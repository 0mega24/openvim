# openvim

A Vim-like text editor for [OpenComputers](https://github.com/MightyPirates/OpenComputers), written in Lua 5.2.

## Install

Paste this into your OC shell (requires an internet card):

```
wget https://raw.githubusercontent.com/0mega24/openvim/main/install.lua install.lua && lua install.lua
```

To install a specific branch or tag:

```
lua install.lua dev
```

Files are installed to `/usr/bin/openvim` and `/usr/lib/vim/`.

## Usage

```
openvim <file>
openvim newfile.lua
```

---

## Modes

openvim is modal, like Vim. The current mode is shown in the status bar at the bottom of the screen.

| Mode | How to enter |
|------|-------------|
| **Normal** | Default mode. `Ctrl+[` or `Esc` from any other mode |
| **Insert** | `i`, `a`, `o`, etc. from Normal |
| **Visual** | `v` from Normal |
| **Command** | `:` from Normal |
| **Search** | `/` or `?` from Normal |

---

## Normal Mode

### Navigation

| Key | Action |
|-----|--------|
| `h` / `←` | Move left |
| `l` / `→` | Move right |
| `j` / `↓` | Move down |
| `k` / `↑` | Move up |
| `w` | Next word start |
| `W` | Next WORD start (whitespace-delimited) |
| `b` | Previous word start |
| `B` | Previous WORD start |
| `e` | Next word end |
| `E` | Next WORD end |
| `0` | Start of line |
| `^` | First non-blank character of line |
| `$` | End of line |
| `gg` | Go to first line |
| `G` | Go to last line |
| `{n}G` | Go to line n (e.g. `10G`) |
| `{n}gg` | Go to line n (e.g. `5gg`) |
| `f{c}` | Find character `c` forward on line |
| `F{c}` | Find character `c` backward on line |
| `t{c}` | Move to just before `c` forward |
| `T{c}` | Move to just after `c` backward |
| `;` | Repeat last `f`/`t`/`F`/`T` |
| `,` | Repeat last `f`/`t`/`F`/`T` in reverse |
| `%` | Jump to matching bracket (`(` `)` `[` `]` `{` `}`) |
| `Ctrl+f` / `PageDown` | Page down |
| `Ctrl+b` / `PageUp` | Page up |
| `Ctrl+d` | Half page down |
| `Ctrl+u` | Half page up |

All motion keys accept a count prefix: `5j` moves down 5 lines, `3w` jumps 3 words forward.

### Scrolling the View

| Key | Action |
|-----|--------|
| `zz` | Centre the current line on screen |
| `zt` | Scroll so current line is at the top |
| `zb` | Scroll so current line is at the bottom |

### Entering Insert Mode

| Key | Action |
|-----|--------|
| `i` | Insert before cursor |
| `a` | Insert after cursor |
| `I` | Insert at start of line |
| `A` | Insert at end of line |
| `gI` | Insert at column 1 (before any indent) |
| `o` | Open new line below and insert |
| `O` | Open new line above and insert |
| `s` | Delete character under cursor and insert |
| `S` | Clear current line and insert |
| `C` | Delete from cursor to end of line and insert |
| `c{motion}` | Delete over motion and insert (see Operators) |

### Editing

| Key | Action |
|-----|--------|
| `x` | Delete character under cursor |
| `X` | Delete character before cursor |
| `r{c}` | Replace character under cursor with `c` |
| `~` | Toggle case of character(s) under cursor |
| `d{motion}` | Delete over motion (see Operators) |
| `dd` | Delete current line |
| `D` | Delete from cursor to end of line |
| `y{motion}` | Yank (copy) over motion |
| `yy` | Yank current line |
| `p` | Paste after cursor / below current line |
| `P` | Paste before cursor / above current line |
| `J` | Join current line with the line below |
| `>` | Indent current line |
| `<` | Dedent current line |
| `u` | Undo |
| `Ctrl+r` | Redo |

### Operators (`d`, `y`, `c`)

Operators combine with a motion to define a region:

| Example | Action |
|---------|--------|
| `dw` | Delete to next word |
| `dW` | Delete to next WORD |
| `db` | Delete back one word |
| `d$` | Delete to end of line |
| `d0` | Delete to start of line |
| `d^` | Delete to first non-blank |
| `df{c}` | Delete up to and including `c` |
| `dt{c}` | Delete up to (not including) `c` |
| `dd` | Delete entire line |
| `cw` | Change word (delete + insert) |
| `cc` | Change entire line |
| `c$` | Change to end of line |
| `yw` | Yank word |
| `y$` | Yank to end of line |

All of the above also accept a count: `3dd` deletes 3 lines, `2dw` deletes 2 words.

### Search

| Key | Action |
|-----|--------|
| `/` | Start forward search |
| `?` | Start backward search |
| `n` | Next match (same direction) |
| `N` | Next match (opposite direction) |
| `*` | Search forward for word under cursor |
| `#` | Search backward for word under cursor |

Patterns are Lua patterns (e.g. `/func` finds "func", `/[%d]+` finds numbers).

### Visual Mode

| Key | Action |
|-----|--------|
| `v` | Enter Visual mode (line selection) |
| Movement keys | Extend selection |
| `d` / `x` | Delete selected lines |
| `y` | Yank selected lines |
| `~` | Toggle case of selection |
| `>` | Indent selected lines |
| `<` | Dedent selected lines |
| `Ctrl+[` | Return to Normal mode |

### Quick Quit / Save

| Key | Action |
|-----|--------|
| `ZZ` | Save and quit |
| `ZQ` | Quit without saving |

---

## Insert Mode

| Key | Action |
|-----|--------|
| `Ctrl+[` | Return to Normal mode |
| `Backspace` | Delete character before cursor |
| `Delete` | Delete character under cursor |
| `Enter` | New line (auto-indents) |
| `Tab` | Insert spaces (width set by `tabwidth`) |
| `Ctrl+w` | Delete word before cursor |
| `Ctrl+u` | Delete from cursor to start of line |
| `←` `→` `↑` `↓` | Move cursor |
| `Home` | Move to start of line |
| `End` | Move to end of line |

---

## Command Mode (`:`)

Enter with `:` from Normal mode. Confirm with `Enter`, cancel with `Ctrl+[`.

### File Commands

| Command | Action |
|---------|--------|
| `:w` | Save current file |
| `:w <file>` | Save to a different file |
| `:e <file>` | Open file (creates it if it doesn't exist) |
| `:e` | Reload current file from disk |
| `:q` | Quit (refuses if there are unsaved changes) |
| `:q!` | Quit without saving |
| `:wq` or `:x` | Save and quit |
| `:source <file>` | Load a vimrc-style config file |

### Navigation

| Command | Action |
|---------|--------|
| `:{n}` | Go to line n |
| `:+{n}` | Move n lines down |
| `:-{n}` | Move n lines up |

### Substitution

| Command | Action |
|---------|--------|
| `:s/pat/repl/` | Replace first match on current line |
| `:s/pat/repl/g` | Replace all matches on current line |
| `:%s/pat/repl/` | Replace first match on every line |
| `:%s/pat/repl/g` | Replace all matches in the file |

Patterns are Lua patterns.

### Settings

| Command | Action |
|---------|--------|
| `:set number` / `:set nu` | Show line numbers |
| `:set nonumber` / `:set nonu` | Hide line numbers |
| `:set rnu` | Use relative line numbers |
| `:set nornu` | Use absolute line numbers |
| `:set cursorline` / `:set cul` | Highlight current line |
| `:set nocursorline` / `:set nocul` | Remove current-line highlight |
| `:set syntax=lua` | Force Lua syntax highlighting |
| `:set syntax=text` | Disable syntax highlighting |
| `:set colorcolumn={n}` | Show a ruler at column n |
| `:set tabstop={n}` / `:set ts={n}` | Set tab/indent width |
| `:set scrolloff={n}` / `:set so={n}` | Lines to keep above/below cursor |

---

## Configuration (`.vimrc`)

openvim loads `/home/.vimrc` on startup if it exists. Any `:set` command that works interactively can be placed there:

```
set rnu
set tabstop=4
set colorcolumn=100
set syntax=lua
```

---

## Status Bar

```
 NORMAL  myfile.lua [+]           lua  42:17
 ╰─ mode ─╯ ╰─ filename ─╯  ╰─ syntax ─╯  ╰─ line:col ─╯
```

`[+]` appears when there are unsaved changes.

---

## Syntax Highlighting

Lua syntax is detected automatically for `.lua` files and includes:

- Keywords (`if`, `while`, `function`, …)
- Built-ins (`print`, `require`, `pairs`, …)
- OpenComputers API names (`component`, `gpu`, `term`, `event`, …) — plus any hardware attached at runtime
- Function calls
- Strings, numbers, and comments (including multi-line `--[[ ]]`)

---

## Differences from Vim

openvim is not a full Vim implementation. Notable omissions:

- No macros (`q`)
- No marks (`` ` `` / `'`)
- No named registers (`"a`)
- No `.` repeat
- No text objects (`ci"`, `da(`, …)
- No split windows or tabs
- Visual mode is linewise only
- Patterns use Lua syntax, not Vim regex
