import Foundation

public enum MachOWalker {

    public static func fatBinaries(in bundleURL: URL) -> [URL] {
        let contents = bundleURL.appending(path: "Contents")
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: contents,
            includingPropertiesForKeys: [
                .isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey,
                .fileSizeKey,
            ],
            options: []
        ) else { return [] }

        var seen: Set<InodeKey> = []
        var results: [URL] = []

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .isSymbolicLinkKey, .isRegularFileKey,
            ]) else { continue }

            if values.isSymbolicLink == true { continue }

            guard values.isRegularFile == true else { continue }

            guard let key = InodeKey(url: url) else { continue }
            if !seen.insert(key).inserted { continue }

            guard isFatMachO(url: url) else { continue }
            results.append(url)
        }

        return results
    }

    static func isFatMachO(url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4), data.count == 4
        else { return false }

        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }

        return magic == 0xCAFE_BABE ||
               magic == 0xBEBA_FECA ||
               magic == 0xCAFE_BABF ||
               magic == 0xBFBA_FECA
    }
}

struct InodeKey: Hashable {
    let device: dev_t
    let inode: ino_t

    init?(url: URL) {
        var st = stat()
        let path = url.path(percentEncoded: false)
        guard lstat(path, &st) == 0 else { return nil }
        self.device = st.st_dev
        self.inode = st.st_ino
    }
}
