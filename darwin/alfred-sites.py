"""Explicit, atomic Alfred site refresh. Activation only initializes public data."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--initialize', action='store_true', help='create public list only if absent; no authentication')
    mode.add_argument('--personal', action='store_true', help='explicitly replace list with public sites only')
    mode.add_argument('--work', action='store_true', help='explicitly authenticate and merge work sites')
    parser.add_argument('--personal-file', required=True)
    parser.add_argument('--op', required=True)
    parser.add_argument('--account', required=True)
    parser.add_argument('--allow-work', action='store_true')
    args = parser.parse_args()
    target = Path.home() / '.config/alfred/sites.json'
    temporary = None
    try:
        if args.initialize and (target.exists() or target.is_symlink()):
            return 0
        if target.is_symlink():
            raise ValueError('Refusing to replace symlink sites.json')
        if args.work and not args.allow_work:
            raise ValueError('Enable programs.alfredWebsiteHelper.enableWorkSites before using --work')
        sites = json.loads(Path(args.personal_file).read_text())
        if not isinstance(sites, list):
            raise ValueError('Invalid public site list')
        if args.work:
            # Deliberate user action may prompt. Bound the wait; never log payload
            # or CLI errors, which can contain sensitive account/item metadata.
            result = subprocess.run(
                [args.op, 'item', 'get', 'work-urls', '--account=' + args.account, '--format=json'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=45, check=True,
            )
            work = json.loads(result.stdout)
            if not isinstance(work, dict) or not isinstance(work.get('fields'), list):
                raise ValueError('Invalid work-site data')
            work_count = 0
            for field in work['fields']:
                if not isinstance(field, dict):
                    raise ValueError('Invalid work-site field')
                if field.get('type') == 'URL':
                    if not isinstance(field.get('label'), str) or not isinstance(field.get('value'), str):
                        raise ValueError('Invalid work-site URL')
                    if not field['label'].strip() or not field['value'].strip():
                        raise ValueError('Empty work-site URL')
                    work_count += 1
                    sites.append({'title': field['label'], 'arg': field['value'],
                                  'icon': str(Path.home() / '.config/alfred/brave.png')})
            if not work_count:
                raise ValueError('No valid work URLs; use --personal to clear work sites')
        target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.sites-', dir=target.parent)
        with os.fdopen(fd, 'w') as stream:
            json.dump(sites, stream)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        if args.initialize:
            # Atomic no-clobber initialization, including concurrent activations.
            try:
                os.link(temporary, target)
            except FileExistsError:
                pass
        else:
            os.replace(temporary, target)
            temporary = None
        print('Alfred sites ready.')
        return 0
    except (OSError, ValueError, subprocess.SubprocessError):
        print('Alfred refresh failed; existing sites were preserved. Check configuration and 1Password access, then retry.', file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            os.unlink(temporary)


if __name__ == '__main__':
    sys.exit(main())
