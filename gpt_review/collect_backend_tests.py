#!/usr/bin/env python3
"""
Collect backend test files and related documentation for GPT review.

This script:
1. Collects test files (Bucket A) - test markdown and shell scripts
2. Collects README and process/guide docs (Bucket B)
3. Creates a combined bundle markdown file
4. Copies individual files with type labels (TEST/DOC/TEST+DOC)
"""

import fnmatch
import os
import shutil
from pathlib import Path
from typing import Dict, List, Set, Tuple


def get_repo_root() -> Path:
    """Determine repository root directory."""
    # Script lives in gpt_review/, so parents[1] gives repo root
    script_path = Path(__file__).resolve()
    return script_path.parents[1]


def is_excluded_path(path: Path, repo_root: Path) -> bool:
    """
    Check if a path should be excluded from scanning.
    
    Excludes:
    - .git
    - node_modules
    - .venv, .idea, .vscode
    - dist, build
    - gpt_review
    - Any hidden folder starting with .
    """
    relative_path = path.relative_to(repo_root)
    path_parts = relative_path.parts
    
    # Check for excluded directory names
    excluded_dirs = {'.git', 'node_modules', '.venv', 'venv', 'env', '.idea', '.vscode', 
                     'dist', 'build', 'gpt_review'}
    
    # Check if any path component is excluded or starts with .
    for part in path_parts:
        if part in excluded_dirs:
            return True
        if part.startswith('.'):
            return True
    
    return False


def is_test_script(path: Path) -> bool:
    """
    Check if a shell script is test-related.
    
    Matches if filename contains: test, check, health, verify
    """
    script_name = path.stem.lower()  # filename without extension
    test_keywords = ['test', 'check', 'health', 'verify']
    return any(keyword in script_name for keyword in test_keywords)


def matches_test_patterns(path: Path, repo_root: Path) -> bool:
    """
    Check if a file matches test file patterns (Bucket A).
    
    Patterns:
    - tests/**/*.md
    - docs/**/*test*.md
    - **/test*.md
    - **/*_test.md
    - **/test*.sh (filtered for test keywords)
    - **/*_test.sh
    - scripts/**/*.sh (filtered for test keywords)
    """
    relative_path = path.relative_to(repo_root)
    path_str = str(relative_path)
    name_lower = path.name.lower()
    
    # Markdown test files
    if path.suffix.lower() == '.md':
        # tests/**/*.md
        if path_str.startswith('tests/'):
            return True
        # docs/**/*test*.md
        if path_str.startswith('docs/') and 'test' in name_lower:
            return True
        # **/test*.md
        if name_lower.startswith('test'):
            return True
        # **/*_test.md
        if name_lower.endswith('_test.md'):
            return True
    
    # Shell test scripts
    if path.suffix.lower() == '.sh':
        # **/test*.sh (filtered)
        if name_lower.startswith('test') and is_test_script(path):
            return True
        # **/*_test.sh
        if name_lower.endswith('_test.sh'):
            return True
        # scripts/**/*.sh (filtered for test keywords)
        if path_str.startswith('scripts/') and is_test_script(path):
            return True
    
    return False


def matches_doc_patterns(path: Path, repo_root: Path) -> bool:
    """
    Check if a file matches README/process doc patterns (Bucket B).
    
    Patterns:
    - Any README*.md
    - docs/**/*.md with keywords in path/filename:
      process, procedure, howto, how_to, guide, runbook, ops, operation,
      deploy, deployment, setup, install, usage, backend, collector,
      data-collection, nsready, ns_ready
    """
    relative_path = path.relative_to(repo_root)
    path_parts = relative_path.parts
    path_str = str(relative_path).lower()
    name_lower = path.name.lower()
    
    if path.suffix.lower() != '.md':
        return False
    
    # README files
    if 'readme' in name_lower:
        return True
    
    # Process/guide docs under docs/ (must be directly under docs/ directory)
    # Check if path starts with 'docs' as the first or second part
    if len(path_parts) > 0 and path_parts[0] == 'docs':
        keywords = [
            'process', 'procedure', 'howto', 'how_to', 'guide', 'runbook',
            'ops', 'operation', 'deploy', 'deployment', 'setup', 'install',
            'usage', 'backend', 'collector', 'data-collection', 'nsready', 'ns_ready'
        ]
        
        # Check if any keyword is in path or filename
        full_text = f"{path_str} {name_lower}"
        if any(keyword in full_text for keyword in keywords):
            return True
    elif len(path_parts) > 1 and path_parts[1] == 'docs':
        # Handle paths like shared/docs/...
        keywords = [
            'process', 'procedure', 'howto', 'how_to', 'guide', 'runbook',
            'ops', 'operation', 'deploy', 'deployment', 'setup', 'install',
            'usage', 'backend', 'collector', 'data-collection', 'nsready', 'ns_ready'
        ]
        
        # Check if any keyword is in path or filename
        full_text = f"{path_str} {name_lower}"
        if any(keyword in full_text for keyword in keywords):
            return True
    
    return False


def collect_files(repo_root: Path) -> Tuple[List[Tuple[Path, str]], List[Tuple[Path, str]]]:
    """
    Collect files into Bucket A (tests) and Bucket B (docs).
    
    Returns:
        (bucket_a, bucket_b) where each is a list of (path, relative_path_str)
    """
    bucket_a = []  # Test files
    bucket_b = []  # README/process docs
    
    # Walk through all files in repo
    for root, dirs, files in os.walk(repo_root):
        root_path = Path(root)
        
        # Filter out excluded directories
        dirs[:] = [d for d in dirs if not is_excluded_path(root_path / d, repo_root)]
        
        for file in files:
            file_path = root_path / file
            
            # Skip excluded paths
            if is_excluded_path(file_path, repo_root):
                continue
            
            relative_path = file_path.relative_to(repo_root)
            
            # Check Bucket A (tests)
            if matches_test_patterns(file_path, repo_root):
                bucket_a.append((file_path, str(relative_path)))
            
            # Check Bucket B (docs)
            if matches_doc_patterns(file_path, repo_root):
                bucket_b.append((file_path, str(relative_path)))
    
    return bucket_a, bucket_b


def deduplicate_and_label(bucket_a: List[Tuple[Path, str]], 
                          bucket_b: List[Tuple[Path, str]]) -> Dict[str, Tuple[Path, str]]:
    """
    Deduplicate files across buckets and assign type labels.
    
    Returns:
        Dict mapping relative_path_str -> (path, type_label)
        Type can be: 'TEST', 'DOC', or 'TEST+DOC'
    """
    files_dict: Dict[str, Tuple[Path, str]] = {}
    
    # Process Bucket A
    for path, rel_path in bucket_a:
        if rel_path not in files_dict:
            files_dict[rel_path] = (path, 'TEST')
        else:
            # File in both buckets - mark as TEST+DOC
            files_dict[rel_path] = (path, 'TEST+DOC')
    
    # Process Bucket B
    for path, rel_path in bucket_b:
        if rel_path not in files_dict:
            files_dict[rel_path] = (path, 'DOC')
        else:
            # File already marked (from Bucket A) - ensure it's TEST+DOC
            if files_dict[rel_path][1] == 'TEST':
                files_dict[rel_path] = (path, 'TEST+DOC')
            # If already TEST+DOC, keep it
    
    return files_dict


def read_file_content(file_path: Path) -> str:
    """
    Read file content with UTF-8, falling back to latin-1.
    
    Returns:
        File content as string
    """
    try:
        return file_path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        return file_path.read_text(encoding='latin-1')


def get_language_tag(file_path: Path) -> str:
    """Get language tag for code fence based on file extension."""
    ext = file_path.suffix.lower()
    if ext == '.md':
        return 'md'
    elif ext == '.sh':
        return 'sh'
    else:
        return 'text'


def create_safe_filename(index: int, file_type: str, relative_path: str) -> str:
    """
    Create safe filename for individual file copy.
    
    Format: <3-digit index>__<TYPE>__<path_with_slashes_as__>
    """
    # Replace slashes with double underscores
    path_safe = relative_path.replace('/', '__').replace('\\', '__')
    return f"{index:03d}__{file_type}__{path_safe}"


def main():
    """Main execution function."""
    repo_root = get_repo_root()
    output_dir = repo_root / 'gpt_review' / 'backend_tests'
    bundle_file = repo_root / 'gpt_review' / 'backend_tests_bundle.md'
    
    print(f"Repository root: {repo_root}")
    print(f"Output directory: {output_dir}")
    print()
    
    # Collect files
    print("Collecting files...")
    bucket_a, bucket_b = collect_files(repo_root)
    print(f"  Bucket A (test files): {len(bucket_a)} files")
    print(f"  Bucket B (README/docs): {len(bucket_b)} files")
    
    # Deduplicate and label
    print("Deduplicating and labeling files...")
    files_dict = deduplicate_and_label(bucket_a, bucket_b)
    total_files = len(files_dict)
    print(f"  Total unique files: {total_files}")
    
    # Count by type
    type_counts = {'TEST': 0, 'DOC': 0, 'TEST+DOC': 0}
    for _, file_type in files_dict.values():
        type_counts[file_type] = type_counts.get(file_type, 0) + 1
    
    print(f"    TEST: {type_counts['TEST']}")
    print(f"    DOC: {type_counts['DOC']}")
    print(f"    TEST+DOC: {type_counts['TEST+DOC']}")
    print()
    
    # Clean output directory
    if output_dir.exists():
        print(f"Cleaning output directory: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Sort files for consistent ordering
    sorted_files = sorted(files_dict.items(), key=lambda x: x[0])
    
    # Separate into buckets for bundle organization
    test_files = [(rel_path, path, file_type) for rel_path, (path, file_type) in sorted_files
                  if file_type in ('TEST', 'TEST+DOC')]
    doc_files = [(rel_path, path, file_type) for rel_path, (path, file_type) in sorted_files
                 if file_type in ('DOC', 'TEST+DOC')]
    
    # Generate bundle markdown
    print(f"Generating bundle file: {bundle_file}")
    with bundle_file.open('w', encoding='utf-8') as f:
        f.write("# Backend Test & Documentation Bundle\n\n")
        f.write(f"- Total files: {total_files}\n")
        f.write(f"- Test files (Bucket A): {len(test_files)}\n")
        f.write(f"- Docs / README (Bucket B): {len(doc_files)}\n\n")
        
        # Section A: Test files
        f.write("## A. Test scripts and test markdown\n\n")
        for idx, (rel_path, path, file_type) in enumerate(test_files, 1):
            f.write(f"### A.{idx} `{rel_path}` ({file_type})\n\n")
            f.write(f"```{get_language_tag(path)}\n")
            try:
                content = read_file_content(path)
                f.write(content)
            except Exception as e:
                f.write(f"ERROR READING FILE: {e}\n")
            f.write("\n```\n\n")
        
        # Section B: README/process docs
        # Include all DOC and TEST+DOC files (TEST+DOC files appear in both sections)
        f.write("## B. README / process / related documentation\n\n")
        for idx, (rel_path, path, file_type) in enumerate(doc_files, 1):
            f.write(f"### B.{idx} `{rel_path}` ({file_type})\n\n")
            f.write(f"```{get_language_tag(path)}\n")
            try:
                content = read_file_content(path)
                f.write(content)
            except Exception as e:
                f.write(f"ERROR READING FILE: {e}\n")
            f.write("\n```\n\n")
    
    print(f"Bundle file created: {bundle_file}")
    
    # Copy individual files
    print(f"Copying individual files to: {output_dir}")
    for idx, (rel_path, (path, file_type)) in enumerate(sorted_files, 1):
        safe_filename = create_safe_filename(idx, file_type, rel_path)
        output_path = output_dir / safe_filename
        
        try:
            content = read_file_content(path)
            output_path.write_text(content, encoding='utf-8')
        except Exception as e:
            print(f"  WARNING: Could not copy {rel_path}: {e}")
    
    print(f"Copied {len(sorted_files)} individual files")
    print()
    
    # Print summary
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"\nBucket A - Test files ({len(test_files)} files):")
    for rel_path, _, file_type in test_files:
        print(f"  [{file_type}] {rel_path}")
    
    print(f"\nBucket B - README / process docs ({len(doc_files)} files):")
    for rel_path, _, file_type in doc_files:
        print(f"  [{file_type}] {rel_path}")
    
    print("\n" + "=" * 80)
    print(f"Total unique files collected: {total_files}")
    print(f"Bundle file: {bundle_file}")
    print(f"Individual files: {output_dir}")
    print("=" * 80)


if __name__ == '__main__':
    main()

