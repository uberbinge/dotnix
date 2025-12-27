{ pkgs, lib, username, ... }:
let
  updateFindCache = pkgs.writeShellApplication {
    name = "update-find-cache.sh";
    runtimeInputs = with pkgs; [ coreutils findutils ];
    text = ''
      CACHE_FILE="$HOME/.cache/wq-find-dir-cache.txt"
      mkdir -p "$HOME/.cache"
      [ -f "$CACHE_FILE" ] && rm "$CACHE_FILE"

      SEARCH_DIRS=(
        "$HOME"
        "$HOME/dev"
        "$HOME/.config"
      )

      # Add work directory if it exists
      [ -d "$HOME/work" ] && SEARCH_DIRS+=("$HOME/work")

      # Temporary file for storing results
      TEMP_FILE=$(mktemp)

      echo "Processing search directories"
      found_dirs=0

      for dir in "''${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
          echo "Searching in $dir"
          while IFS= read -r subdir; do
            if [[ "$(uname)" == "Darwin" ]]; then
              mtime=$(/usr/bin/stat -f '%m' "$subdir" 2>/dev/null || echo 0)
            else
              mtime=$(stat --format=%Y "$subdir" 2>/dev/null || echo 0)
            fi
            if [[ "$mtime" =~ ^[0-9]+$ && $mtime -gt 0 ]]; then
              echo "$mtime $subdir" >> "$TEMP_FILE"
              ((found_dirs++)) || true
            fi
          done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d \
            ! -name ".*" \
            ! -path "*/Downloads" \
            ! -path "*/Documents" \
            ! -path "*/Movies" \
            ! -path "*/Pictures" \
            ! -path "*/Music" \
            ! -path "*/Library" \
            ! -path "*/Desktop" \
            ! -path "*/Applications" 2>/dev/null)
        fi
      done

      # Sort by mtime (descending) and ensure unique paths
      if [ -s "$TEMP_FILE" ]; then
        sort -nr "$TEMP_FILE" > "$CACHE_FILE"
        echo "Created cache file with $found_dirs directories"
      else
        echo "No directories found"
      fi

      # Clean up
      rm -f "$TEMP_FILE"

      if [ ! -s "$CACHE_FILE" ]; then
        echo "Error: Cache file $CACHE_FILE is empty or was not created"
        exit 1
      fi
    '';
  };

  tmuxSessionizer = pkgs.writeShellApplication {
    name = "tmux-sessionizer";
    runtimeInputs = with pkgs; [ fzf tmux coreutils findutils ];
    text = ''
      # Cache expires after 24 hours (in seconds)
      CACHE_EXPIRY=$((24 * 3600))
      CACHE_FILE="$HOME/.cache/wq-find-dir-cache.txt"

      # Function to update the cache file with fresh directory listings
      update_cache() {
        if ! update-find-cache.sh; then
          echo "Error: Failed to update cache file $CACHE_FILE" >&2
          return 1
        fi
      }

      # Get current time for cache expiry calculation
      current_time=$(date +%s)

      # Check if cache file exists and determine its modification time
      if [[ -f "$CACHE_FILE" && -r "$CACHE_FILE" ]]; then
        # Handle different stat commands for macOS and Linux
        if [[ "$(uname)" == "Darwin" ]]; then
          cache_file_mtime=$(/usr/bin/stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        else
          cache_file_mtime=$(stat --format=%Y "$CACHE_FILE" 2>/dev/null || echo 0)
        fi
        # Validate the modification time is a number
        if ! [[ "$cache_file_mtime" =~ ^[0-9]+$ ]]; then
          echo "Warning: Invalid cache file mtime, forcing update" >&2
          cache_file_mtime=0
        fi
      else
        # Cache file doesn't exist or isn't readable
        cache_file_mtime=0
      fi

      # Update cache if it's expired or doesn't exist
      if [[ $cache_file_mtime -eq 0 || $((current_time - cache_file_mtime)) -gt $CACHE_EXPIRY ]]; then
        update_cache || {
          echo "Error: Cache update failed, exiting" >&2
          exit 1
        }
      fi

      # Handle directory selection
      if [[ $# -eq 1 ]]; then
        # If a directory is provided as an argument, use it directly
        selected=$1
      else
        # Otherwise, use fzf to select from the cached directories
        if ! [ -s "$CACHE_FILE" ]; then
          echo "Error: Cache file $CACHE_FILE is empty or does not exist" >&2
          exit 1
        fi
        # Use fzf for fuzzy finding, showing only the directory name in the list
        if ! selected=$(cut -d' ' -f2- "$CACHE_FILE" | fzf --tmux --no-sort --delimiter="/" --nth=-1 --with-nth=-1); then
          echo "Error: No directory selected or cache file is invalid" >&2
          exit 1
        fi
      fi

      # Exit if no directory was selected
      if [[ -z "$selected" ]]; then
        exit 0
      fi

      # Create a valid tmux session name from the directory name
      selected_name=$(basename "$selected" | tr . _)
      tmux_running=$(pgrep tmux || true)

      # If tmux isn't running, start a new session
      if [[ -z "''${TMUX:-}" ]] && [[ -z "$tmux_running" ]]; then
        tmux new-session -s "$selected_name" -c "$selected"
        exit 0
      fi

      # Create the session if it doesn't exist
      if ! tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux new-session -ds "$selected_name" -c "$selected"
      fi

      # Attach to the session or switch to it if already in tmux
      if [[ -z "''${TMUX:-}" ]]; then
        tmux attach-session -t "$selected_name"
      else
        tmux switch-client -t "$selected_name"
      fi
    '';
  };
in
{
  # Add scripts to PATH via home.packages (cleaner than home.file)
  home.packages = [
    updateFindCache
    tmuxSessionizer
  ];
}
