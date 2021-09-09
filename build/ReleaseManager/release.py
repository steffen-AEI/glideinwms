#!/usr/bin/env python3 -B

import sys
import os
import optparse

# Necessary to allow relative import when started as executable
if __name__ == "__main__" and __package__ is None:
    # append the parent directory to the path
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    __package__ = "ReleaseManager"
    # This was suggested on line but seems not needed
    #mod = __import__("ReleaseManager")
    #sys.modules["ReleaseManager"] = mod

try:
    from .ReleaseManagerLib import *
except (SystemError, ImportError) as e:
    # Try also absolute import. Should not be needed
    from ReleaseManagerLib import *


def manager_version():
    try:
        if os.path.exists("/var/lib/gwms-factory/work-dir/checksum.factory"):
            chksum_file = "checksum.factory"
        elif os.path.exists("/var/lib/gwms-frontend/vofrontend/checksum.frontend"):
            chksum_file = "checksum.frontend"
        from glideinwms.lib import glideinWMSVersion
    except ImportError:
        return "UNKNOWN"
    try:
        return glideinWMSVersion.GlideinWMSDistro(chksum_file).version()
    except RuntimeError:
        return "UNKNOWN"


def usage():
    help = ["%s <version> <SourceDir> <ReleaseDir>" % os.path.basename(sys.argv[0]),
            "NOTE that this script works on the files in your current directory tree",
            "- no git operations like clone/checkout are performed",
            "- files you changed are kept so",
            "- if using big files you should run 'bigfiles.sh -pr' before invoking this script",
            "  and 'bigfiles -R' after, to ripristinate the symlinks before a commit"
            "Example: Release Candidate rc3 for v3.2.11 (ie version v3_2_11_rc3)",
            "         Generate tarball: glideinWMS_v3_2_11_rc3*.tgz",
            "         Generate rpms   : glideinWMS-*-v3.2.11-0.4.rc3-*.rpm",
            "release.py --release-version=3_2_11 --rc=4 --source-dir=/home/parag/glideinwms --release-dir=/var/tmp/release --rpm-release=4 --rpm-version=3.2.11",
            "",
            "Example: Final Release v3.2.11",
            "         Generate tarball: glideinWMS_v3_2_11*.tgz",
            "         Generate rpms   : glideinWMS-*-v3.2.11-3-*.rpm",
            "release.py --release-version=3_2_11 --source-dir=/home/parag/glideinwms --release-dir=/var/tmp/release --rpm-release=3 --rpm-version=3.2.11",
            "",
            ]
    return '\n'.join(help)


def parse_opts(argv):
    parser = optparse.OptionParser(usage=usage(),
                                   version=manager_version(),
                                   conflict_handler="resolve")
    parser.add_option('--release-version',
                      dest='relVersion',
                      action='store',
                      metavar='<release version>',
                      help='glideinwms version to release')
    parser.add_option('--source-dir',
                      dest='srcDir',
                      action='store',
                      metavar='<source directory>',
                      help='directory containing the glideinwms source code')
    parser.add_option('--release-dir',
                      dest='relDir',
                      default='/tmp/release',
                      action='store',
                      metavar='<release directory>',
                      help='directory to store release tarballs and webpages')
    parser.add_option('--rc',
                      dest='rc',
                      default=None,
                      action='store',
                      metavar='<Release Candidate Number>',
                      help='Release Candidate')
    parser.add_option('--rpm-release',
                      dest='rpmRel',
                      default=1,
                      action='store',
                      metavar='<RPM Release Number>',
                      help='RPM Release Number')
    parser.add_option('--rpm-version',
                      dest='rpmVer',
                      action='store',
                      metavar='<Product Version in RPM filename>',
                      help='Product Version in RPM filename')

    if len(argv) == 2 and argv[1] in ['-v', '--version']:
        parser.print_version()
        sys.exit()
    if len(argv) < 4:
        print("ERROR: Insufficient arguments specified")
        parser.print_help()
        sys.exit(1)
    options, remainder = parser.parse_args(argv)
    if len(remainder) > 1:
        parser.print_help()
    if not required_args_present(options):
        print("ERROR: Missing required arguments")
        parser.print_help()
        sys.exit(1)
    return options


def required_args_present(options):
    try:
        if ((options.relVersion is None) or
            (options.srcDir is None) or
            (options.relDir is None)):
            return False
    except AttributeError:
        return False
    return True


#   check_required_args


# def main(ver, srcDir, relDir):
def main(argv):
    options = parse_opts(argv)
    # sys.exit(1)
    ver = options.relVersion
    srcDir = options.srcDir
    relDir = options.relDir
    rc = options.rc
    rpmRel = options.rpmRel

    print("___________________________________________________________________")
    print("Creating following glideinwms release")
    print(
        "Version=%s\nSourceDir=%s\nReleaseDir=%s\nReleaseCandidate=%s\nRPMRelease=%s" %
        (ver, srcDir, relDir, rc, rpmRel))
    print("___________________________________________________________________")
    print()
    rel = Release(ver, srcDir, relDir, rc, rpmRel)

    rel.addTask(TaskClean(rel))
    rel.addTask(TaskSetupReleaseDir(rel))
    rel.addTask(TaskVersionFile(rel))
    rel.addTask(TaskTar(rel))
    rel.addTask(TaskRPM(rel))

    rel.executeTasks()
    rel.printReport()


if __name__ == "__main__":
    main(sys.argv)
