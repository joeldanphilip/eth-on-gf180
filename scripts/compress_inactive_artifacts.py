"""Losslessly compact inactive generated files, verifying every archive."""
import concurrent.futures
import gzip
import hashlib
import json
import os
from pathlib import Path
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
build = root/'build'
paths = []
for name in ['physical', 'physical_compat', 'physical_compat_rc', 'physical_decoupled']:
    paths += [p for p in (build/name/'results').rglob('*')
              if p.is_file() and not p.is_symlink() and p.suffix in {'.odb', '.def', '.v', '.il'}]
protected = {'gf180_read_onehot_finish', 'gf180_read_onehot',
             'gf180_decoupled_read', 'gf180_physical_pipeline',
             'gf180_physical_pipeline_final', 'gf180_lvs'}
for directory in build.glob('gf180*'):
    if directory.is_dir() and directory.name not in protected:
        paths += [p for p in directory.glob('*')
                  if p.is_file() and not p.is_symlink() and p.suffix in {'.il', '.json', '.v', '.lib'}]
manifest = {'utc': datetime.now(timezone.utc).isoformat(),
            'operation': 'verified reversible gzip conversion; no evidence discarded',
            'restore': 'gunzip path/to/file.gz', 'files': []}
record = build/('inactive_artifact_compression_' + datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S') + '.json')

def compact(source):
    before = source.stat()
    target = source.with_name(source.name+'.gz')
    if target.exists():
        raise RuntimeError(f'Archive already exists; refusing overwrite: {target}')
    temporary = target.with_name(target.name+'.tmp')
    digest = hashlib.sha256()
    with source.open('rb') as inp, gzip.open(temporary, 'wb', compresslevel=1) as out:
        while chunk := inp.read(1024*1024):
            digest.update(chunk)
            out.write(chunk)
    verify = hashlib.sha256()
    with gzip.open(temporary, 'rb') as inp:
        while chunk := inp.read(1024*1024):
            verify.update(chunk)
    assert verify.digest() == digest.digest(), source
    after = source.stat()
    assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), source
    temporary.replace(target)
    os.utime(target, ns=(before.st_atime_ns, before.st_mtime_ns))
    # The verified gzip is a byte-for-byte recoverable replacement.
    source.unlink()
    return {'source': str(source.relative_to(root)), 'archive': str(target.relative_to(root)),
            'sha256': digest.hexdigest(), 'original_bytes': before.st_size,
            'compressed_bytes': target.stat().st_size}

with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
    for item in executor.map(compact, sorted(set(paths))):
        manifest['files'].append(item)
        record.write_text(json.dumps(manifest, indent=2)+'\n')
        print(item['archive'], flush=True)
saved = sum(x['original_bytes']-x['compressed_bytes'] for x in manifest['files'])
print(json.dumps({'verified_archives': len(manifest['files']),
                  'reclaimed_GiB': round(saved/1024**3, 2), 'manifest': str(record)}), flush=True)
