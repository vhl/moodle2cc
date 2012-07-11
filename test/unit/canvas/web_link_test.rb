require 'nokogiri'
require 'minitest/autorun'
require 'test/test_helper'
require 'moodle2cc'

class TestUnitCCWebLink < MiniTest::Unit::TestCase
  include TestHelper

  def setup
    convert_moodle_backup
    @mod = @backup.course.mods.find { |m| m.mod_type == "resource" && m.type == "file" }
  end

  def teardown
    clean_tmp_folder
  end

  def test_it_converts_id
    @mod.id = 123

    web_link = Moodle2CC::CC::WebLink.new @mod
    assert_equal 123, web_link.id
  end

  def test_it_converts_title
    @mod.name = "About Your Instructor"

    web_link = Moodle2CC::CC::WebLink.new @mod
    assert_equal "About Your Instructor", web_link.title
  end

  def test_it_converts_url
    @mod.reference = "http://en.wikipedia.org/wiki/Einstein"

    web_link = Moodle2CC::CC::WebLink.new @mod
    assert_equal "http://en.wikipedia.org/wiki/Einstein", web_link.url
  end

  def test_it_has_an_identifier
    @mod.id = 123

    web_link = Moodle2CC::CC::WebLink.new @mod
    assert_equal 'iecc4b622fbc1adf8b8a2085e0974ac7d', web_link.identifier
  end

  def test_it_creates_resource_in_imsmanifest
    web_link = Moodle2CC::CC::WebLink.new @mod
    node = Builder::XmlMarkup.new
    xml = Nokogiri::XML(web_link.create_resource_node(node))

    resource = xml.xpath('resource').first
    assert resource
    assert_equal 'imswl_xmlv1p1', resource.attributes['type'].value
    assert_equal 'i15aaccec404aa2ad557108a689bbba8f', resource.attributes['identifier'].value

    file = resource.xpath('file[@href="i15aaccec404aa2ad557108a689bbba8f.xml"]').first
    assert file
  end

  def test_it_creates_item_in_module_meta
    @mod.reference = "http://www.google.com/some-doc.html"
    web_link = Moodle2CC::CC::WebLink.new @mod
    node = Builder::XmlMarkup.new
    xml = Nokogiri::XML(web_link.create_module_meta_item_node(node, 5))

    assert_equal 'item', xml.root.name
    assert_equal 'i966437b815a49aad86a356bc8aa8f24a', xml.root.attributes['identifier'].value
    assert_equal "About Your Instructor", xml.root.xpath('title').text
    assert_equal '5', xml.root.xpath('position').text
    assert_equal '', xml.root.xpath('new_tab').text
    assert_equal '1', xml.root.xpath('indent').text
    assert_equal 'http://www.google.com/some-doc.html', xml.root.xpath('url').text
    assert_equal 'ExternalUrl', xml.root.xpath('content_type').text
    assert_equal 'i15aaccec404aa2ad557108a689bbba8f', xml.root.xpath('identifierref').text

    @mod.reference = "some/local/file.html"
    web_link = Moodle2CC::CC::WebLink.new @mod
    node = Builder::XmlMarkup.new
    xml = Nokogiri::XML(web_link.create_module_meta_item_node(node, 5))

    assert_equal '', xml.root.xpath('url').text
    assert_equal 'Attachment', xml.root.xpath('content_type').text
  end

  def test_it_creates_xml
    @mod.id = 123
    @mod.name = "About Your Instructor"
    @mod.reference = "http://en.wikipedia.org/wiki/Einstein"

    tmp_dir = File.expand_path('../../../tmp', __FILE__)
    web_link = Moodle2CC::CC::WebLink.new @mod
    web_link.create_xml(tmp_dir)
    xml = Nokogiri::XML(File.read(File.join(tmp_dir, "#{web_link.identifier}.xml")))

    assert xml
    assert_equal "http://www.imsglobal.org/xsd/imsccv1p1/imswl_v1p1 http://www.imsglobal.org/profile/cc/ccv1p1/ccv1p1_imswl_v1p1.xsd", xml.root.attributes['schemaLocation'].value
    assert_equal "http://www.w3.org/2001/XMLSchema-instance", xml.namespaces['xmlns:xsi']
    assert_equal "http://www.imsglobal.org/xsd/imsccv1p1/imswl_v1p1", xml.namespaces['xmlns']
    assert_equal web_link.identifier, xml.xpath('xmlns:webLink').first.attributes['identifier'].value

    assert_equal "About Your Instructor", xml.xpath('xmlns:webLink/xmlns:title').text
    assert xml.xpath('xmlns:webLink/xmlns:url[@href="http://en.wikipedia.org/wiki/Einstein"]').first
  end
end