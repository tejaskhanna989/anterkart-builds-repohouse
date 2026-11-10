import re
import sys
import os

# Get the flutter.groovy path from command line argument, or use default
if len(sys.argv) > 1:
    flutter_groovy = sys.argv[1]
else:
    flutter_groovy = r'/opt/hostedtoolcache/flutter/stable-3.24.3-x64/flutter/packages/flutter_tools/gradle/src/main/groovy/flutter.groovy'

print(f'Patching: {flutter_groovy}')

with open(flutter_groovy, 'r') as f:
    content = f.read()

print(f'Original file size: {len(content)}')

# Replace all occurrences of project.exec { ... } with ProcessBuilder-compatible code
# Pattern: project.exec { ... }
pattern = re.compile(
    r'(?:project|rootProject)\.exec\s*\{[^}]*\}',
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
    # Debug: show what's in the file
    if 'exec(' in content:
        print("Found 'exec(' in file")
        # Find all occurrences
        for m in re.finditer(r'\w+\.exec\s*\{', content):
            idx = m.start()
            print(f"  Found 'exec()' at position {idx}: ...{content[max(0,idx-50):idx+150]}...")
    else:
        print("'exec(' not found in file")
        # Show first 500 chars of file to understand its structure
        print(f"First 500 chars: ...{content[:500]}...")

with open(flutter_groovy, 'w') as f:
    f.write(new_content)

print(f'New file size: {len(new_content)}')
