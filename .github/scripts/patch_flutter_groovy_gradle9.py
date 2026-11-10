#!/usr/bin/env python3
"""
Patch Flutter Gradle Plugin for Gradle 9 compatibility.
Replaces project.exec() calls with ProcessBuilder-compatible code.
"""
import re
import sys
import os

# Get the Flutter Gradle Plugin directory from command line argument
if len(sys.argv) > 1:
    flutter_gradle_dir = sys.argv[1]
else:
    flutter_gradle_dir = r'/opt/hostedtoolcache/flutter/stable-3.24.3-x64/flutter/packages/flutter_tools/gradle'

print(f'Patching Flutter Gradle Plugin in: {flutter_gradle_dir}')

# Find all Gradle-related files (.groovy, .gradle.kts, .kt)
flutter_files = []
for root, dirs, files in os.walk(flutter_gradle_dir):
    for file in files:
        if file.endswith(('.groovy', '.gradle.kts', '.gradle', '.kt')):
            flutter_files.append(os.path.join(root, file))

print(f'Found {len(flutter_files)} Gradle files in Flutter plugin')

total_patched = 0

for flutter_file in flutter_files:
    with open(flutter_file, 'r') as f:
        content = f.read()

    # Pattern: project.exec { ... } or rootProject.exec { ... }
    pattern = re.compile(
        r'(?:rootProject|project)\.exec\s*\{[^}]*\}',
        re.DOTALL
    )

    new_code = '''def gradlewCmd = rootProject.projectDir.toString() + "/gradlew"
def proc = [gradlewCmd, ":${subproject.name}:dependencies", "--write-locks"].execute()
proc.directory = rootProject.projectDir
proc.waitFor()'''

    new_content, count = pattern.subn(new_code, content)

    if count > 0:
        print(f"Patched {count} occurrence(s) of exec() in {flutter_file}")
        with open(flutter_file, 'w') as f:
            f.write(new_content)
        total_patched += count

if count > 0:
    print(f"\nTotal: Patched {count} occurrence(s) of exec() in Flutter Gradle Plugin")
else:
    print("WARNING: No exec() calls found to patch!")
    print("Searching for 'exec(' in Flutter Gradle Plugin files...")
    for flutter_file in flutter_files:
        with open(flutter_file, 'r') as f:
            content = f.read()
        if 'exec(' in content:
            print(f"  Found 'exec(' in {flutter_file}")
            for m in re.finditer(r'\w+\.exec\s*\{', content):
                idx = m.start()
                print(f"    'exec()' at position {idx}: ...{content[max(0,idx-50):idx+200]}...")