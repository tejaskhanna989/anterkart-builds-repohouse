#!/usr/bin/env python3
"""
Patch Flutter Gradle Plugin for Gradle 9 compatibility.
Replaces project.exec() calls with ProcessBuilder-compatible code.
"""
import re
import sys

flutter_groovy = sys.argv[1] if len(sys.argv) > 1 else '/opt/hostedtoolcache/flutter/stable-3.24.3-x64/flutter/packages/flutter_tools/gradle/src/main/groovy/flutter.groovy'

print(f'Patching: {flutter_groovy}')

with open(flutter_groovy, 'r') as f:
    content = f.read()

print(f'Original file size: {len(content)}')

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
    print(f"Patched {count} occurrence(s) of exec() in flutter.groovy")
else:
    print("WARNING: No exec() call found to patch!")
    if 'exec(' in content:
        print("Found 'exec(' in file")
        for m in re.finditer(r'\w+\.exec\s*\{', content):
            idx = m.start()
            print(f"  Found 'exec()' at position {idx}: ...{content[max(0,idx-50):idx+200]}...")
    else:
        print("'exec(' not found in file")
        print(f"First 500 chars: ...{content[:500]}...")

with open(flutter_groovy, 'w') as f:
    f.write(new_content)

print(f'New file size: {len(new_content)}')
