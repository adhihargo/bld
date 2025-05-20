"""
Post-load handler to record blend file version in module-level variable
`file_version_list`. Executed directly, it will collect version of all opened
files and print them to stdout.
"""

import atexit
import logging
from collections import namedtuple

import bpy
from bpy.app.handlers import persistent

logger = logging.getLogger(__name__)
FileVersionInfo = namedtuple("FileVersionInfo", ["version", "filepath"])
file_version_list = []


@persistent
def collect_fileversion(filename):
    filepath = bpy.data.filepath
    if filepath:
        file_version_list.append(FileVersionInfo(bpy.data.version, filepath))


def print_and_pause_before_exit():
    if not file_version_list:
        logger.error("No file opened")
    for version_info in file_version_list:
        print("BLENDERv{1}||{0.filepath}".format(version_info, ".".join(map(str, version_info.version))))


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    bpy.app.handlers.load_post.append(collect_fileversion)
    atexit.register(print_and_pause_before_exit)
