import re
import sys

# Get the flutter.groovy path from command line argument, or use default
if len(sys.argv) > 1:
    flutter_groovy = sys.argv[1]
else:
    flutter_groovy = r'C:\hostedtoolcache\windows\flutter\stable-3.22.0-x64\flutter\packages\flutter_tools\gradle\src\main\groovy\flutter.groovy'

print(f'Patching: {flutter_groovy}')

with open(flutter_groovy, 'r') as f:
    content = f.read()

print(f'Original file size: {len(content)}')

# 1. Remove the groovy.xml.QName import
content = re.sub(r'import groovy\.xml\.QName\s*\n', '', content)

# 2. Remove the groovy.xml.XmlParser import
content = re.sub(r'import groovy\.xml\.XmlParser\s*\n', '', content)

# 3. Replace QName with javax.xml.namespace.QName (standard Java API)
content = re.sub(r'\bQName\b', 'javax.xml.namespace.QName', content)

# 4. Add necessary imports - find the right place to insert them
# The imports needed for the newXmlParser helper
required_imports = '''import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.parsers.DocumentBuilder
import org.w3c.dom.Document
import org.w3c.dom.Node
import org.w3c.dom.NodeList
import org.w3c.dom.Element
import org.xml.sax.InputSource
import java.io.StringReader
'''

# Check if imports already exist
if 'DocumentBuilderFactory' not in content:
    # Try to find package declaration and add imports after it
    package_match = re.search(r'(^package .*\n)', content, re.MULTILINE)
    if package_match:
        # Add imports after package declaration
        insert_pos = package_match.end()
        content = content[:insert_pos] + '\n' + required_imports + '\n' + content[insert_pos:]
    else:
        # No package declaration, add at the beginning after any shebang/comments
        # Find first non-comment, non-empty line
        lines = content.split('\n')
        insert_idx = 0
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped and not stripped.startswith('//') and not stripped.startswith('/*') and not stripped.startswith('*'):
                insert_idx = i
                break
        lines.insert(insert_idx, required_imports)
        content = '\n'.join(lines)

# 5. Replace XmlParser usage with newXmlParser()
content = re.sub(r'new XmlParser\(\)', 'newXmlParser()', content)
content = re.sub(r'new groovy\.util\.XmlParser\(\)', 'newXmlParser()', content)
content = re.sub(r'new groovy\.xml\.XmlParser\(\)', 'newXmlParser()', content)

# 6. Add the newXmlParser helper method and XmlSlurperAdapter class
# Find the first 'def ' or 'class ' and insert before it
helper_code = """

def newXmlParser() {
  return [parse: { input ->
    def factory = DocumentBuilderFactory.newInstance()
    def builder = factory.newDocumentBuilder()
    def inputSource = new InputSource(new StringReader(input))
    def doc = builder.parse(inputSource)
    return new XmlSlurperAdapter(doc)
  }]
}

class XmlSlurperAdapter {
  Document doc
  XmlSlurperAdapter(Document doc) { this.doc = doc }
  def getAt(String name) {
    def nodes = doc.getElementsByTagName(name)
    if (nodes.getLength() == 0) return null
    if (nodes.getLength() == 1) return new XmlSlurperAdapter(nodes.item(0))
    def list = []
    for (int i = 0; i < nodes.getLength(); i++) {
      list << new XmlSlurperAdapter(nodes.item(i))
    }
    return list
  }
  String toString() { doc.getTextContent() }
}

"""

# Find the first 'def ' or 'class ' at the beginning of a line and insert before it
match = re.search(r'(^def |^class )', content, re.MULTILINE)
if match:
    insert_pos = match.start()
    content = content[:insert_pos] + helper_code + content[insert_pos:]
else:
    # If no def or class found, append at the end
    content = content + '\n' + helper_code

# Write the patched file
with open(flutter_groovy, 'w') as f:
    f.write(content)

print('Patched flutter.groovy successfully')

# Verify the imports were added
if 'DocumentBuilderFactory' in content and 'InputSource' in content and 'Document' in content:
    print('VERIFIED: Required imports are present in patched file')
else:
    print('WARNING: Some required imports may be missing!')
    if 'DocumentBuilderFactory' not in content:
        print('  - Missing: DocumentBuilderFactory')
    if 'InputSource' not in content:
        print('  - Missing: InputSource')
    if 'Document' not in content:
        print('  - Missing: Document')