require 'minitest/autorun'
require 'test/test_helper'
require 'moodle2cc'

class TestUnitCanvasAssessment < MiniTest::Unit::TestCase
  include TestHelper

  def setup
    convert_moodle_backup('canvas')
    @mod = @backup.course.mods.find { |m| m.mod_type == "quiz" }
    @assessment = Moodle2CC::Canvas::Assessment.new @mod
  end

  def teardown
    clean_tmp_folder
  end

  def test_it_inherits_from_cc
    assert Moodle2CC::Canvas::Assessment.ancestors.include?(Moodle2CC::CC::Assessment), 'does not inherit from base CC class'
  end

  def test_it_has_a_non_cc_assessments_identifier
    @mod.id = 321
    assessment = Moodle2CC::Canvas::Assessment.new @mod
    assert_equal 'ibe158496fef4c2255274cdf9113e1daf', assessment.non_cc_assessments_identifier
  end

  def test_it_creates_resource_in_imsmanifest
    node = Builder::XmlMarkup.new
    xml = Nokogiri::XML(@assessment.create_resource_node(node))

    resource = xml.xpath('resource').first
    assert resource
    assert_equal 'associatedcontent/imscc_xmlv1p1/learning-application-resource', resource.attributes['type'].value
    assert_equal 'i058d7533a77712b6e7757b34e66df7fc/assessment_meta.xml', resource.attributes['href'].value
    assert_equal 'ibe158496fef4c2255274cdf9113e1daf', resource.attributes['identifier'].value

    file = resource.xpath('file[@href="i058d7533a77712b6e7757b34e66df7fc/assessment_meta.xml"]').first
    assert file

    file = resource.xpath('file[@href="non_cc_assessments/i058d7533a77712b6e7757b34e66df7fc.xml.qti"]').first
    assert file
  end

  def test_it_creates_item_in_module_meta
    node = Builder::XmlMarkup.new
    xml = Nokogiri::XML(@assessment.create_module_meta_item_node(node, 5))

    assert_equal 'item', xml.root.name
    assert_equal 'if474f80fb2019d59f25ff2a96c9aa381', xml.root.attributes['identifier'].value
    assert_equal "First Quiz", xml.root.xpath('title').text
    assert_equal '5', xml.root.xpath('position').text
    assert_equal '', xml.root.xpath('new_tab').text
    assert_equal '0', xml.root.xpath('indent').text
    assert_equal 'Quiz', xml.root.xpath('content_type').text
    assert_equal 'i058d7533a77712b6e7757b34e66df7fc', xml.root.xpath('identifierref').text
  end

  def test_it_creates_assessment_meta_xml
    tmp_dir = File.expand_path('../../../tmp', __FILE__)
    @assessment.create_assessment_meta_xml(tmp_dir)
    xml = Nokogiri::XML(File.read(File.join(tmp_dir, @assessment.identifier, 'assessment_meta.xml')))

    assert xml
    assert_equal "http://canvas.instructure.com/xsd/cccv1p0 http://canvas.instructure.com/xsd/cccv1p0.xsd", xml.root.attributes['schemaLocation'].value
    assert_equal "http://www.w3.org/2001/XMLSchema-instance", xml.namespaces['xmlns:xsi']
    assert_equal "http://canvas.instructure.com/xsd/cccv1p0", xml.namespaces['xmlns']
    assert_equal @assessment.identifier, xml.xpath('xmlns:quiz').first.attributes['identifier'].value

    assert_equal 'First Quiz', xml.xpath('xmlns:quiz/xmlns:title').text
    assert_equal 'Pop quiz hot shot', xml.xpath('xmlns:quiz/xmlns:description').text
    assert_equal '2012-06-11T18:50:00', xml.xpath('xmlns:quiz/xmlns:unlock_at').text
    assert_equal '2012-06-12T18:50:00', xml.xpath('xmlns:quiz/xmlns:lock_at').text
    assert_equal '45', xml.xpath('xmlns:quiz/xmlns:time_limit').text
    assert_equal '2', xml.xpath('xmlns:quiz/xmlns:allowed_attempts').text
    assert_equal 'keep_highest', xml.xpath('xmlns:quiz/xmlns:scoring_policy').text
    assert_equal 'password', xml.xpath('xmlns:quiz/xmlns:access_code').text
    assert_equal '127.0.0.1', xml.xpath('xmlns:quiz/xmlns:ip_filter').text
    assert_equal 'true', xml.xpath('xmlns:quiz/xmlns:shuffle_answers').text
  end

  def test_it_creates_qti_xml
    tmp_dir = File.expand_path('../../../tmp', __FILE__)
    @assessment.create_qti_xml(tmp_dir)
    xml = Nokogiri::XML(File.read(File.join(tmp_dir, 'non_cc_assessments', "#{@assessment.identifier}.xml.qti")))

    assert xml
    assert_equal "http://www.imsglobal.org/xsd/ims_qtiasiv1p2 http://www.imsglobal.org/xsd/ims_qtiasiv1p2p1.xsd", xml.root.attributes['schemaLocation'].value
    assert_equal "http://www.w3.org/2001/XMLSchema-instance", xml.namespaces['xmlns:xsi']
    assert_equal "http://www.imsglobal.org/xsd/ims_qtiasiv1p2", xml.namespaces['xmlns']
    assert_equal 'questestinterop', xml.root.name

    assert_equal "First Quiz", xml.root.xpath('xmlns:assessment').first.attributes['title'].value
    assert_equal @assessment.identifier, xml.root.xpath('xmlns:assessment').first.attributes['identifier'].value

    time_data = xml.root.xpath('xmlns:assessment/xmlns:qtimetadata/xmlns:qtimetadatafield[xmlns:fieldlabel="qmd_timelimit" and xmlns:fieldentry="45"]').first
    assert time_data, 'qtimetadata does not exist for time limit'

    time_data = xml.root.xpath('xmlns:assessment/xmlns:qtimetadata/xmlns:qtimetadatafield[xmlns:fieldlabel="cc_maxattempts" and xmlns:fieldentry="2"]').first
    assert time_data, 'qtimetadata does not exist for max attempts'

    section = xml.root.xpath('xmlns:assessment/xmlns:section[@ident="root_section"]').first
    assert section, 'root sections node does not exist'

    items = xml.root.xpath('xmlns:assessment/xmlns:section/xmlns:item')
    assert_equal 5, items.length
  end
end