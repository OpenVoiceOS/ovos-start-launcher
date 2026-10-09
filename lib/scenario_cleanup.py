"""Remove only the finished wizard's scenario, as its original unprivileged user."""
import os
import stat
import sys


def identity(info: os.stat_result) -> tuple[int, int]:
    """Identify an inode without following a pathname or symlink."""
    return info.st_dev, info.st_ino


def cleanup(config: int, staging: int, folder_name: str) -> None:
    """Use inherited directory handles and quarantine before identity deletion."""
    owned = os.stat("owned", dir_fd=staging, follow_symlinks=False)
    if not stat.S_ISREG(owned.st_mode):
        return
    try:
        active = os.stat("scenario.yaml", dir_fd=config, follow_symlinks=False)
        if stat.S_ISREG(active.st_mode) and identity(active) == identity(owned):
            os.rename("scenario.yaml", "candidate", src_dir_fd=config, dst_dir_fd=staging)
            captured = os.stat("candidate", dir_fd=staging, follow_symlinks=False)
            if stat.S_ISREG(captured.st_mode) and identity(captured) == identity(owned):
                os.unlink("candidate", dir_fd=staging)
            else:
                # Never overwrite a racing writer or follow a new destination
                # directory. If restoration fails, retain the captured object.
                try:
                    os.link("candidate", "scenario.yaml", src_dir_fd=staging,
                            dst_dir_fd=config, follow_symlinks=False)
                    os.unlink("candidate", dir_fd=staging)
                except OSError:
                    pass
    except FileNotFoundError:
        pass
    for name in ("owned", "active"):
        try:
            os.unlink(name, dir_fd=staging)
        except FileNotFoundError:
            pass
    # Remove only an empty staging directory still associated with this handle.
    folder = os.stat(folder_name, dir_fd=config, follow_symlinks=False)
    if stat.S_ISDIR(folder.st_mode) and identity(folder) == identity(os.fstat(staging)):
        os.rmdir(folder_name, dir_fd=config)


if __name__ == "__main__":
    try:
        cleanup(4, 6, sys.argv[1])
    except OSError:
        # Setup's actual exit status must survive any permission or cleanup error.
        pass
