"""Quick and dirty script that uses hardcoded paths and ugly parsing method
   to demonstrate the clang-without-gcc concept with an ARM-EABI target
"""
import os
import sys

# The following paths should be automatically updated on installation
XTOOLCHAIN=""
NEWLIB=""
COMPILER_RT=""

if not XTOOLCHAIN:
    raise AssertionError("Xtoolchain is not defined")

options = []

if '-Wl' in [x[:3] for x in sys.argv if x.startswith('-')]:
    #print "Linker mode"
    tool = 'ld'
    relocatable = False
    incremental = False
    stdlib = True
    extras = []
    xarch = 'armv4t'
    if not NEWLIB or not COMPILER_RT:
        raise AssertionError("Library paths are not defined")
    skip = False
    for arg in sys.argv[1:]:
        if skip:
            skip = False
            if not arg.startswith('-'):
                continue
        if arg.startswith('-f'):
            continue
        if arg.startswith('-mcpu'):  # should we?
            continue
        if arg.startswith('-std='):
            continue
        if arg.startswith('-Wl,'):
            arg = arg[4:]
        if arg.startswith('-W'):
            continue
        if arg.startswith('-f'):
            continue
        if arg.startswith('--sysroot'):
            continue
        if arg.startswith('-D') or arg.startswith('-U'):
            skip = True
            continue
        if arg.startswith('-l'):
            extras.append(arg)
            continue
        if arg == '-pipe':
            # cause a 'bad -rpath option' for some reason
            continue
        if arg == '-nostdlib':
            stdlib = False
        if arg == '-r':
            relocatable = True
        if arg == '-r':
            incremental = True
        options.append(arg)
    options.append('-L%s/%s/lib' % (NEWLIB, XTOOLCHAIN))
    options.append('-L%s/lib/%s' % (COMPILER_RT, xarch))
    # libraries should be placed AFTER .o files
    options.extend(extras)
    for pos, opt in enumerate(options):
        if opt.startswith('-l'):
            break
    # Do not link against runtime when building the toolchain
    if not relocatable and not incremental:
        # runtime may contain reference to libc symbols, such as memcpy...
        # add it before the very first library specifier
        # other libraries may rely on runtime symbols, so add it another time
        # options.append('-lcompiler_rt')
        if stdlib:
            options.append('--start-group')
            options.append('-lc')
        options.append('-lcompiler_rt')
        if stdlib:
            options.append('--end-group')
    if '--Map' in options:
        # fix map file path if any so that it is created in the same directory
        # as the output file.
        try:
            outpos = options.index('-o')
            outpath = os.path.dirname(options[outpos+1])
            mappos = options.index('--Map')
            options[mappos+1] = os.path.join(outpath, options[mappos+1])
        except Exception, e:
            print "Error", e
else:
    if verbose:
        print >> sys.stderr, "Assembler mode"
    tool = 'as'
    skip = False
    for arg in sys.argv[1:]:
        if skip:
            skip = False
            if not arg.startswith('-'):
                continue
        if arg in ('-nostdsysteminc', '-nobuiltininc', '-nostdinc',
                   '-nostdlib', '-nostartfiles'):
            continue
        if arg.startswith('-f'):
            continue
        if arg.startswith('-W'):
            continue
        if arg.startswith('-M'):
            skip = True
            continue
        if arg.startswith('-D') or arg.startswith('-U'):
            skip = True
            continue
        if arg.startswith('-c'):
            continue
        if arg.startswith('-O'):
            continue
        if arg.startswith('--sysroot'):
            continue
        if arg.startswith('-std'):
            continue
        if arg.startswith('-pipe'):
            continue
        if arg.startswith('-x'):
            skip = True
            continue
        if arg.startswith('-L') or arg.startswith('-T'):
            if len(arg) < 3:
                skip = True
            continue
        if arg.startswith('-B'):
            arg = '-I%s' % arg[2:]
        if arg.startswith('-isystem'):
            arg = '-I%s' % arg[8:]
        options.append(arg)
cmd = '%s-%s %s' % (XTOOLCHAIN, tool, ' '.join(options))
rc = os.system(cmd)
if rc:
    print >> sys.stderr, 'Failed command:'
    print >> sys.stderr, ' ', cmd
    if verbose:
        for opt in options:
            print >> sys.stderr, " ", opt
sys.exit(rc and 1 or 0)
