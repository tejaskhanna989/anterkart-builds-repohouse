import re

flutter_groovy = r'C:\hostedtoolcache\windows\flutter\3.22.0\x64\flutter\packages\flutter_tools\gradle\src\main\groovy\flutter.groovy'

with open(flutter_groovy, 'r') as f:
    content = f.read()

print(f'Original file size: {len(content)}')

# 1. Remove the groovy.xml.QName import
content = re.sub(r'import groovy\.xml\.QName\s*\n', '', content)

# 2. Remove the groovy.xml.XmlParser import
content = re.sub(r'import groovy\.xml\.XmlParser\s*\n', '', content)

# 3. Replace QName with javax.xml.namespace.QName (standard Java API)
content = re.sub(r'\bQName\b', 'javax.xml.namespace.QName', content)

# 4. Add necessary imports after package declaration
imports = '''import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.parsers.DocumentBuilder
import org.w3c.dom.Document
import org.w3c.dom.Node
import org.w3c.dom.NodeList
import org.w3c.dom.Element
import org.xml.sax.InputSource
import java.io.StringReader
'''

# Add imports after package declaration
content = re.sub(r'(^package .*\n)', r'\1\n' + imports + '\n', content, count=1)

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

# Find the first 'def ' or 'class ' and insert before it
content = re.sub(r'(^def |^class )', helper_code + r'\1', content, count=1, flags=re.MULTILINE)

# Write the patched file
with open(r'C:\hostedtoolcache\windows\flutter\3.22.0\x64\flutter\packages\flutter_tools\gradle\src\main\groovy\flutter.groovy', 'w') as f:
    f.write(content)

print('Patched flutter.groovy successfully')