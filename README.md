# Vanilla_oCB
A player castbar replacement as well as a target castbar.

## Credits
- haste for original work
- AtheneGenesis
- laytya for backporting better config options
- shagu for borrowing the target cast combat parser from

### New features
- Now comes with a target castbar
- `/ocb` for options

### Caveats
- For player spells the highest rank available is chosen where cast times differ.
- The internal spell database has been extracted from the client files with a filter on non-instant, interruptible, non-dummy spells.

### Third-party addons
- [FuBar_ToFu](https://github.com/Road-block/FuBar_ToFu/releases/latest) can plug into oCB to show flight timers it records.
