import Darwin
import Foundation

public enum BrowserProfileLock {

    public static func chromiumUserDataIsLocked(_ userDataDirectory: URL) -> Bool {
        let lock = userDataDirectory.appending(path: "SingletonLock").path(percentEncoded: false)
        var info = stat()
        return lstat(lock, &info) == 0
    }

    public static func firefoxProfileIsLocked(_ profileDirectory: URL) -> Bool {
        let lockPath = profileDirectory.appending(path: ".parentlock").path(percentEncoded: false)
        let fd = open(lockPath, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var query = flock()
        query.l_type = Int16(F_WRLCK)
        query.l_whence = Int16(SEEK_SET)
        query.l_start = 0
        query.l_len = 0
        guard fcntl(fd, F_GETLK, &query) == 0 else {

            return true
        }
        return query.l_type != Int16(F_UNLCK)
    }
}
