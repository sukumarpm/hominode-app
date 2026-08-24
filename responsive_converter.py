import os
import shutil
import subprocess
import sys
import re
from pathlib import Path

BACKUP_DIR_NAME = ".dart_backups"

def backup_file(file_path: Path) -> Path:
    backup_dir = file_path.parent / BACKUP_DIR_NAME
    backup_dir.mkdir(parents=True, exist_ok=True)
    destination = backup_dir / file_path.name
    shutil.copy2(file_path, destination)
    print(f"✓ Backup created/updated at: {destination}")
    return destination

def apply_responsive_sizing(file_path: Path):
    content = file_path.read_text(encoding="utf-8")
    
    # 1. Ensure ScreenUtil import is present
    import_statement = "import 'package:flutter_screenutil/flutter_screenutil.dart';"
    if import_statement not in content:
        content = f"{import_statement}\n" + content

    # 2. Convert numbers to ScreenUtil extensions
    patterns = [
        (r"\bfontSize:\s*([0-9]+(?:\.[0-9]+)?)\b", r"fontSize: \1.sp"),
        (r"\bheight:\s*([0-9]+(?:\.[0-9]+)?)\b", r"height: \1.h"),
        (r"\bwidth:\s*([0-9]+(?:\.[0-9]+)?)\b", r"width: \1.w"),
        (r"\bRadius\.circular\(\s*([0-9]+(?:\.[0-9]+)?)\s*\)", r"Radius.circular(\1.r)"),
        (r"\bEdgeInsets\.all\(\s*([0-9]+(?:\.[0-9]+)?)\s*\)", r"EdgeInsets.all(\1.r)"),
        (
            r"\bEdgeInsets\.symmetric\(\s*horizontal:\s*([0-9]+(?:\.[0-9]+)?)\s*,\s*vertical:\s*([0-9]+(?:\.[0-9]+)?)\s*\)",
            r"EdgeInsets.symmetric(horizontal: \1.w, vertical: \2.h)",
        ),
    ]

    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)

    # 3. Clean up double extensions (e.g. 16.w.w -> 16.w)
    content = re.sub(r"\.(w|h|sp|r)\.(w|h|sp|r)\b", r".\1", content)

    # 4. Remove `const` keywords preceding expressions that now use .w, .h, .sp, .r
    # Fixes: const TextStyle(fontSize: 14.sp) -> TextStyle(fontSize: 14.sp)
    # Fixes: const EdgeInsets.all(16.r) -> EdgeInsets.all(16.r)
    # Fixes: const SizedBox(height: 10.h) -> SizedBox(height: 10.h)
    content = re.sub(
        r"\bconst\s+([A-Z][a-zA-Z0-9_\.]*\s*\([^)]*\.(?:sp|w|h|r)\b)",
        r"\1",
        content,
        flags=re.DOTALL
    )
    
    # General cleanup for inline consts preceding properties with extensions
    lines = content.splitlines()
    cleaned_lines = []
    for line in lines:
        if re.search(r"\.(sp|w|h|r)\b", line) and "const " in line:
            # Strip const modifier from the line containing screenutil extensions
            line = re.sub(r"\bconst\s+", "", line)
        cleaned_lines.append(line)

    content = "\n".join(cleaned_lines)

    file_path.write_text(content, encoding="utf-8")
    print("✓ Converted layout values to ScreenUtil units (.w, .h, .sp, .r) and fixed const expressions.")

def run_flutter_analyze_and_fix(target_path: Path):
    print("\n[Running] dart fix --apply to clean up invalid const modifiers and lints...")
    
    # Run dart fix from the directory of the target project
    project_dir = target_path.parent
    while project_dir != project_dir.parent and not (project_dir / "pubspec.yaml").exists():
        project_dir = project_dir.parent

    working_dir = str(project_dir) if (project_dir / "pubspec.yaml").exists() else None

    fix_result = subprocess.run(
        ["dart", "fix", "--apply"], 
        cwd=working_dir,
        capture_output=True, 
        text=True
    )
    print(fix_result.stdout)

    print("[Running] flutter analyze...")
    recheck = subprocess.run(
        ["flutter", "analyze", target_path.name], 
        cwd=str(target_path.parent),
        capture_output=True, 
        text=True
    )
    if recheck.returncode == 0:
        print("✓ All analyze issues resolved successfully!")
    else:
        print("⚠️ Analysis result:\n")
        print(recheck.stdout)

def main():
    if len(sys.argv) < 2:
        file_input = input("Enter full path of the Dart module: ").strip()
    else:
        file_input = sys.argv[1].strip()

    target_path = Path(file_input).resolve()

    if not target_path.exists() or target_path.suffix != ".dart":
        print(f"❌ Error: Valid Dart file not found at: {target_path}")
        sys.exit(1)

    print(f"\nProcessing file: {target_path}")
    backup_file(target_path)
    apply_responsive_sizing(target_path)
    run_flutter_analyze_and_fix(target_path)

if __name__ == "__main__":
    main()
