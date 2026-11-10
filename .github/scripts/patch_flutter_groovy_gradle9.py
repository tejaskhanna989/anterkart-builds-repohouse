#!/usr/bin/env python3
"""
Patch Flutter Gradle Plugin for Gradle 9 compatibility.
Replaces project.exec() calls with ProcessBuilder-compatible code.
"""
import re
import sys
import os

# Get the flutter.groovy path from command line argument
if len(sys.argv) > 1:
    flutter_groovy = sys.argv[1]
else:
    flutter_groovy = r'/opt/hostedtoolcache/flutter/stable-3.24.3-x64/flutter/packages/flutter_tools/gradle/src/main/groovy/flutter.groovy'

print(f'Patching: {flutter_groovy}')

with open(flutter_groovy, 'r') as f:
    content = f.read()

print(f'Original file size: {len(content)}')

# Pattern 1: rootProject.exec { workingDir(...) executable(...) args(...) }
pattern1 = re.compile(
    r'rootProject\.exec\s*\{\s*'
    r'workingDir\(rootProject\.projectDir\)\s*'
    r'executable\(gradlew\)\s*'
    r'args\([^)]*\)\s*\}',
    re.DOTALL
)

# Pattern 2: rootProject.exec { ... } more general pattern
pattern2 = re.compile(
    r'rootProject\.exec\s*\{[^}]*\}',
    re.DOTALL
)

# Pattern 3: project.exec { ... } (more general)
pattern3 = re.compile(
    r'project\.exec\s*\{[^}]*\}',
    re.DOTALL
)

new_code = '''def gradlewCmd = rootProject.projectDir.toString() + "/gradlew"
def proc = [gradlewCmd, ":${subproject.name}:dependencies", "--write-locks"].execute()
proc.directory = rootProject.projectDir
proc.waitFor()'''

new_content, count = pattern1.subn(new_code, content)

if count == 0:
    new_content, count = pattern2.subn(new_code, content)

if count == 0:
    new_content, count = pattern3.subn(new_code, content)

if count > 0:
    print(f"Patched {count} occurrence(s) of exec() in flutter.groovy")
else:
    print("WARNING: No exec() call found to patch!")
    # Debug: show what's in the file
    if 'exec(' in content:
        print("Found 'exec(' in file")
        idx = content.index('exec(')
        print(f"Context around first exec(): ...{content[max(0,idx-100):idx+200]}...")
    else:
        print("'exec(' not found in file")
        # Show first 500 chars of file to understand its structure
        print(f"First 500 chars: ...{content[:500]}...")

with open(flutter_groovy, 'w') as f:
    f.write(new_content)

print(f'New file size: {len(new_content)}')