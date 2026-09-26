# darwin/mini/homebrew.nix
# Mac Mini ONLY - apps not needed on other machines
{ ... }:
{
  homebrew = {
    brews = [
      "ollama"  # Local embeddings for tt-coach RAG (mxbai-embed-large)
    ];
    casks = [
      "jellyfin"  # Native media server with Apple Silicon optimization
    ];
  };
}
