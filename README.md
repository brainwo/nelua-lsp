Nelua LSP
=========

Features:
* Diagnostics
* Hover
* Code completion
* Go to definition

## Usage

Launch command:
```bash
nelua --script path/to/nelua-lsp.lua
```

Example language server configuration for coc.nvim:
```json
{
  "languageserver": {
    "nelua": {
      "command": "nelua",
      "args": [
        "--script",
        "<nelua-lsp-path>/nelua-lsp.lua",
        "--add-path",
        "<nelua-lsp-path>"
      ],
      "filetypes": ["nelua"]
    }
}
```
