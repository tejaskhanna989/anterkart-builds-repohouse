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

# Replace rootProject.exec { ... } closure with ProcessBuilder compatible with Gradle 9
# The pattern matches: rootProject.exec { workingDir(rootProject.projectDir) executable(gradlew) args(...) }
pattern = re.compile(r'rootProject\.exec\s*\{\s*workingDir\(rootProject\.projectDir\)\s*executable\(gradlew\)\s*args\([^)]*\)\s*\}')

new_code = '''def gradlewCmd = rootProject.projectDir.toString() + "/gradlew"
def proc = [gradlewCmd, ":${subproject.name}:dependencies", "--write-locks"].execute()
proc.directory = rootProject.projectDir
proc.waitFor()'''

new_content, count = pattern.subn(new_code, content)

if count > 0:
    print(f"Patched {count} occurrence(s) of exec() in flutter.groovy")
else:
    print("WARNING: No exec() call found to patch!")
    # Let's see what's in the file around rootProject.exec
    if 'rootProject.exec' in content:
        print("Found 'rootProject.exec' in file")
        idx = content.index('rootProject.exec')
        print(f"Context: ...{content[idx:idx+200]}...")
    else:
        print("'rootProject.exec' not found in file")

with open(flutter_groovy, 'w') as f:
    f.write(new_content)

print(f'New file size: {len(new_content)}')
