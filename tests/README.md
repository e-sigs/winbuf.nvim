# Regression tests

Tested on Neovim 0.11.6 on Linux with Python 3 and `pynvim` (Ubuntu package
`python3-pynvim`). No plugin dependencies or application repositories are needed.
Other Neovim versions have not been validated by this suite's current run.

From the checkout root:

```
python3 tests/run.py
```

Each case starts `nvim --clean --embed --headless`, attaches an RPC UI, and checks
ordered memberships, displayed buffers, layout and unsaved text. Prompt choices
are injected deterministically for Save/Discard/Cancel and save-error checks.
Mouse cases use actual `nvim_input_mouse` press/release events on rendered winbars
in an unfocused editor, including a shared modified buffer. They do not call the
mouse handlers directly. These are automated UI checks, not end-to-end terminal
transport tests or distribution-wide integration claims.

Coverage includes cancellation, unsuccessful/unnamed saves, actual displayed
references outside tracked groups, last-editor closing with sidebar/float/another
tabpage, inactive modified files on whole-group close, winfixbuf/switch failures,
subsequent tracking, move failures, excluded windows, winbar ownership, split
inheritance, ordinary closure, and repeated empty-editor closes.

To reproduce the original defects against the audited upstream baseline:

```
git worktree add --detach /tmp/winbuf-baseline 40ac3b9e2589bff8d7451cb1c5f5b3ba214cb656
WINBUF_UNDER_TEST=/tmp/winbuf-baseline python3 tests/reproduce.py
```

Choose a new temporary worktree path if that one is in use. `reproduce.py` asserts
that each bug is present: native delete refusal, callback cancellation, last editor
with a sidebar, stuck suppression after winfixbuf failure, special-window winbar
overwrite, and real unfocused-window mouse targeting. It is intentionally not a
passing regression test for the fixed branch.
