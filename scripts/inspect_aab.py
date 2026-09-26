import zipfile
import os
import sys

def inspect_aab(aab_path):
    print(f"Inspecting AAB: {aab_path}")
    if not os.path.exists(aab_path):
        print("File does not exist!")
        return

    with zipfile.ZipFile(aab_path, 'r') as z:
        infolist = z.infolist()
        total_uncompressed = sum(x.file_size for x in infolist)
        total_compressed = sum(x.compress_size for x in infolist)
        actual_size = os.path.getsize(aab_path)
        print(f"Total files: {len(infolist)}")
        print(f"Total uncompressed: {total_uncompressed:,} bytes ({total_uncompressed/1024/1024:.2f} MB)")
        print(f"Total compressed: {total_compressed:,} bytes ({total_compressed/1024/1024:.2f} MB)")
        print(f"Actual file size: {actual_size:,} bytes ({actual_size/1024/1024:.2f} MB)")

        groups = {}
        for x in infolist:
            parts = x.filename.split('/')
            if parts[0] == 'base' and len(parts) > 1:
                prefix = f"base/{parts[1]}"
            elif parts[0] == 'BUNDLE-METADATA' and len(parts) > 1:
                prefix = f"BUNDLE-METADATA/{parts[1]}"
            else:
                prefix = parts[0]

            if prefix not in groups:
                groups[prefix] = {'count': 0, 'raw': 0, 'comp': 0}
            groups[prefix]['count'] += 1
            groups[prefix]['raw'] += x.file_size
            groups[prefix]['comp'] += x.compress_size

        print("\n=== TOP LEVEL DIRECTORIES (by compressed size) ===")
        for p, d in sorted(groups.items(), key=lambda i: i[1]['comp'], reverse=True):
            pct = (d['comp'] / actual_size) * 100
            print(f"{p:<35} | {d['count']:>5} files | {d['raw']/1024/1024:>7.2f} MB raw | {d['comp']/1024/1024:>7.2f} MB comp | {pct:>5.1f}%")

        # Native libraries breakdown
        print("\n=== NATIVE LIBRARIES (base/lib/) BY ABI ===")
        abi_groups = {}
        so_files = []
        for x in infolist:
            if x.filename.startswith("base/lib/"):
                parts = x.filename.split('/')
                if len(parts) >= 4:
                    abi = parts[2]
                    libname = parts[3]
                    if abi not in abi_groups:
                        abi_groups[abi] = {'count': 0, 'raw': 0, 'comp': 0, 'libs': []}
                    abi_groups[abi]['count'] += 1
                    abi_groups[abi]['raw'] += x.file_size
                    abi_groups[abi]['comp'] += x.compress_size
                    abi_groups[abi]['libs'].append((libname, x.file_size, x.compress_size))
                so_files.append((x.filename, x.file_size, x.compress_size))

        for abi, d in sorted(abi_groups.items(), key=lambda i: i[1]['comp'], reverse=True):
            pct = (d['comp'] / actual_size) * 100
            print(f"ABI {abi:<15} | {d['count']:>3} .so files | {d['raw']/1024/1024:>6.2f} MB raw | {d['comp']/1024/1024:>6.2f} MB comp | {pct:>5.1f}%")

        print("\n=== ALL NATIVE LIBRARIES SORTED BY RAW SIZE ===")
        for f, raw, comp in sorted(so_files, key=lambda i: i[1], reverse=True):
            print(f"{f:<60} | {raw/1024/1024:>6.2f} MB raw | {comp/1024/1024:>6.2f} MB comp")

        print("\n=== TOP 25 LARGEST FILES OVERALL IN AAB (BY COMPRESSED SIZE) ===")
        for x in sorted(infolist, key=lambda i: i.compress_size, reverse=True)[:25]:
            pct = (x.compress_size / actual_size) * 100
            print(f"{x.filename:<75} | {x.file_size/1024/1024:>6.2f} MB raw | {x.compress_size/1024/1024:>6.2f} MB comp | {pct:>5.1f}%")

        # Check BUNDLE-METADATA
        print("\n=== BUNDLE-METADATA CONTENTS ===")
        for x in infolist:
            if x.filename.startswith("BUNDLE-METADATA"):
                print(f"{x.filename:<75} | {x.file_size/1024/1024:>6.2f} MB raw | {x.compress_size/1024/1024:>6.2f} MB comp")

if __name__ == '__main__':
    aab = "build/app/outputs/bundle/release/app-release.aab"
    if len(sys.argv) > 1:
        aab = sys.argv[1]
    inspect_aab(aab)
