require_relative 'spec_helper'

describe "RDE" do

  before(:all) do
    @repo = create(:repo, :repo_code => "rde_test_#{Time.now.to_i}")
    set_repo @repo

    @archivist_user = create_user(@repo => ['repository-archivists'])

    @driver = Driver.new.login_to_repo(@archivist_user, @repo)

    @resource = create(:resource)
    run_index_round
  end


  after(:all) do
    @driver.quit
  end

  it "can view the RDE form when editing a resource" do
    # navigate to the edit resource page
    @driver.get_edit_page(@resource)

    @driver.find_element(:link, "Rapid Data Entry").click
    @driver.wait_for_ajax

    modal = @driver.find_element(:id => "rapidDataEntryModal")
    modal.find_element(:id, "archival_record_children_children__0__level_")
  end

  it "can review error messages on an invalid entry" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".modal-footer .btn-primary").click

    # general message at the top
    modal.find_element_with_text('//div[contains(@class, "alert-danger")]', /1 row\(s\) with an error \- click a row field to view the errors for that row/)

    # simulate focusing the row (normally done when the user focuses on an :input within the row)
    @driver.execute_script("$('#archival_record_children_children__0__title_').closest('tr').addClass('last-focused')")
    @driver.find_element(:css, ".error-summary")
    modal.find_element_with_text('//div[contains(@class, "error")]', /Level of Description - Property is required but was missing/)

    modal.find_element(:id, "archival_record_children_children__0__dates__0__date_type_").select_option("single")
    modal.find_element(:css, ".modal-footer .btn-primary").click

    # make sure this form post is done.. then continue..
    @driver.wait_for_ajax

    # general message at the top
    modal.find_element_with_text('//div[contains(@class, "alert-danger")]', /1 row\(s\) with an error \- click a row field to view the errors for that row/)

    # simulate focusing the row (normally done when the user focuses on an :input within the row)
    @driver.execute_script("$('#archival_record_children_children__0__title_').closest('tr').addClass('last-focused')")
    @driver.find_element(:css, ".error-summary")
    modal.find_element_with_text('//div[contains(@class, "error")]', /Level of Description \- Property is required but was missing/)
    modal.find_element_with_text('//div[contains(@class, "error")]', /Expression \- is required unless a begin or end date is given/)
    modal.find_element_with_text('//div[contains(@class, "error")]', /Begin \- is required unless an expression or an end date is given/)
    modal.find_element_with_text('//div[contains(@class, "error")]', /End \- is required unless an expression or a begin date is given/)
  end

  it "can add a child via the RDE form" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:id, "archival_record_children_children__0__level_").select_option("item")
    @driver.clear_and_send_keys([:id, "archival_record_children_children__0__title_"], "My AO")
    @driver.clear_and_send_keys([:id, "archival_record_children_children__0__dates__0__begin_"], "2013")

    @driver.click_and_wait_until_gone(:css => ".modal-footer .btn-primary")

    @driver.wait_for_ajax

    expect {
      @driver.find_element_with_text("//div[@id='archives_tree']//li//span", /My AO, 2013/)
      @driver.find_element_with_text("//div[@id='archives_tree']//li//span", /Item/)
    }.not_to raise_error
  end

  it "can access the RDE form when editing an archival object" do
    @driver.find_element(:css, "#archives_tree_toolbar .btn-next-tree-node").click
    @driver.wait_for_ajax

    expect {
      assert(5) {
        @driver.find_element(:id, "archival_object_title_")
      }
    }.not_to raise_error

    expect {
      @driver.find_element(:link, "Rapid Data Entry").click
      @driver.find_element(:id => "rapidDataEntryModal")
    }.not_to raise_error
  end


  it "can add multiple children and sticky columns stick" do
    @modal = @driver.find_element(:id => "rapidDataEntryModal")

    @modal.find_element(:id, "archival_record_children_children__0__level_").select_option("fonds")
    @modal.find_element(:id, "archival_record_children_children__0__dates__0__date_type_").select_option("single")
    @modal.find_element(:id, "archival_record_children_children__0__publish_").click
    @driver.clear_and_send_keys([:id, "archival_record_children_children__0__dates__0__begin_"], "2013")
    @driver.clear_and_send_keys([:id, "archival_record_children_children__0__title_"], "Child 1")

    @driver.find_element_with_text("//div[@id='rapidDataEntryModal']//th", /Title/).click

    @modal.find_element(:css, ".btn.add-row").click
    @modal.find_element(:id, "archival_record_children_children__1__level_").get_select_value.should eq("fonds")
    @modal.find_element(:id, "archival_record_children_children__1__dates__0__date_type_").get_select_value.should eq("single")
    @modal.find_element(:id, "archival_record_children_children__1__publish_" ).attribute("checked").should be_truthy
    @modal.find_element(:id, "archival_record_children_children__1__dates__0__begin_").attribute("value").should eq("2013")
    @modal.find_element(:id, "archival_record_children_children__1__title_").attribute("value").should eq("Child 1")

    @driver.clear_and_send_keys([:id, "archival_record_children_children__1__title_"], "Child 2")

    @driver.click_and_wait_until_gone(:css => ".modal-footer .btn-primary")
    @driver.wait_for_ajax

    assert(5) {
      @driver.find_element_with_text("//div[@id='archives_tree']//li//span", /Child 1, 2013/)
      @driver.find_element_with_text("//div[@id='archives_tree']//li//span", /Child 2, 2013/)
    }
  end

  it "can add multiple rows in one action" do
    @driver.find_element(:link, "Rapid Data Entry").click
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:id, "archival_record_children_children__0__level_").select_option("fonds")
    modal.find_element(:id, "archival_record_children_children__0__publish_").click

    modal.find_element(:css, ".btn.add-rows-dropdown").click
    #7.times { @modal.find_element(:css, ".add-rows-form input").send_keys(:arrow_up) }
    @driver.wait_for_ajax
    @driver.clear_and_send_keys([:css, ".add-rows-form input"], "9")

    # this is stupid, but seems to be a flakey issue with Selenium,
    # especially when headless. The key is not being sent, so we'll try the
    # up arrow method to add the rows

    stupid = modal.find_element(:css, ".add-rows-form input").attribute('value')
    unless stupid == '9'
      9.times { modal.find_element(:css, ".add-rows-form input").send_keys(:arrow_up) }
    end
    @driver.wait_for_ajax
    modal.find_element(:css, ".add-rows-form .btn.btn-primary").click
    @driver.wait_for_ajax

    # there should be 10 rows now :)
    modal.find_elements(:css, "table tbody tr").length.should eq(10)

    # all should have fonds as the level
    modal.find_element(:id, "archival_record_children_children__1__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__2__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__3__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__4__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__5__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__6__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__7__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__8__level_").get_select_value.should eq("fonds")
    modal.find_element(:id, "archival_record_children_children__9__level_").get_select_value.should eq("fonds")

    (1..9).each do |id|
      modal.find_element(:id, "archival_record_children_children__#{id}__publish_" ).attribute("checked").should be_truthy
    end

  end

  it "can perform a basic fill" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".btn.fill-column").click
    modal.find_element(:id, "basicFillTargetColumn").select_option("colLevel")
    modal.find_element(:id, "basicFillValue").select_option("item")
    @driver.click_and_wait_until_gone(:css, "#fill_basic .btn-primary")

    # all should have item as the level
    modal.find_element(:id, "archival_record_children_children__0__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__1__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__2__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__3__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__4__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__5__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__6__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__7__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__8__level_").get_select_value.should eq("item")
    modal.find_element(:id, "archival_record_children_children__9__level_").get_select_value.should eq("item")
  end

  it "can perform a sequence fill", :retry => 2, :retry_wait => 10 do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".btn.fill-column").click
    modal.find_element(:link, "Sequence").click

    modal.find_element(:id, "sequenceFillTargetColumn").select_option("colCompId")
    @driver.clear_and_send_keys([:id, "sequenceFillPrefix"], "ABC")
    @driver.clear_and_send_keys([:id, "sequenceFillFrom"], "1")
    @driver.clear_and_send_keys([:id, "sequenceFillTo"], "5")
    @driver.click_and_wait_until_gone(:css, "#fill_sequence .btn-primary")

    # message should be displayed "not enough in the sequence" or thereabouts..
    modal.find_element(:id, "sequenceTooSmallMsg")

    @driver.clear_and_send_keys([:id, "sequenceFillTo"], "10")
    @driver.click_and_wait_until_gone(:css, "#fill_sequence .btn-primary")

    # check the component id for each row matches the sequence
    modal.find_element(:id, "archival_record_children_children__0__component_id_").attribute("value").should eq("ABC1")
    modal.find_element(:id, "archival_record_children_children__1__component_id_").attribute("value").should eq("ABC2")
    modal.find_element(:id, "archival_record_children_children__2__component_id_").attribute("value").should eq("ABC3")
    modal.find_element(:id, "archival_record_children_children__3__component_id_").attribute("value").should eq("ABC4")
    modal.find_element(:id, "archival_record_children_children__4__component_id_").attribute("value").should eq("ABC5")
    modal.find_element(:id, "archival_record_children_children__5__component_id_").attribute("value").should eq("ABC6")
    modal.find_element(:id, "archival_record_children_children__6__component_id_").attribute("value").should eq("ABC7")
    modal.find_element(:id, "archival_record_children_children__7__component_id_").attribute("value").should eq("ABC8")
    modal.find_element(:id, "archival_record_children_children__8__component_id_").attribute("value").should eq("ABC9")
    modal.find_element(:id, "archival_record_children_children__9__component_id_").attribute("value").should eq("ABC10")
  end

  it "can perform a column reorder" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".btn.reorder-columns").click

    # move Note Type 1 to the first position
    modal.find_element(:id, "columnOrder").select_option("colNType1")
    24.times { modal.find_element(:id, "columnOrderUp").click }

    # move Instance Type to the second position
    modal.find_element(:id, "columnOrder").select_option("colNType1") # deselect Note Type 1
    modal.find_element(:id, "columnOrder").select_option("colIType")
    16.times { modal.find_element(:id, "columnOrderUp").click }

    # apply the new order
    @driver.click_and_wait_until_gone(:css, "#columnReorderForm .btn-primary")

    # check the first few headers now match the new order
    cells = modal.find_elements(:css, "table .fieldset-labels th")
    cells[2].attribute("id").should eq("colNType1")
    cells[3].attribute("id").should eq("colIType")
    cells[4].attribute("id").should eq("colOtherLevel")

    # check the section headers are correct
    cells = modal.find_elements(:css, "table .sections th")
    cells[2].text.should eq("Notes")
    cells[2].attribute("colspan").should eq("1")
    cells[3].text.should eq("Instance")
    cells[3].attribute("colspan").should eq("1")
    cells[4].text.should eq("Basic Information")
    cells[4].attribute("colspan").should eq("5")

    # check the form fields match the headers
    cells = modal.find_elements(:css, "table tbody tr:first-child td")
    cells[2].find_element(:id, "archival_record_children_children__0__notes__0__type_")
    cells[3].find_element(:id, "archival_record_children_children__0__instances__0__instance_type_")
    cells[4].find_element(:id, "archival_record_children_children__0__other_level_")
  end
end


describe "Digital Object RDE" do

  before(:all) do
    @repo = create(:repo, :repo_code => "rde_test_#{Time.now.to_i}")
    set_repo @repo

    @archivist_user = create_user(@repo => ['repository-archivists'])

    @digital_object = create(:digital_object)
    @driver = Driver.new.login_to_repo(@archivist_user, @repo)
    run_index_round
  end


  after(:all) do
    @driver.quit
  end

  it "can view the RDE form when editing a digital object" do
    # navigate to the edit resource page
    @driver.get_edit_page(@digital_object)

    @driver.find_element(:link, "Rapid Data Entry").click
    @driver.wait_for_ajax

    modal = @driver.find_element(:id => "rapidDataEntryModal")
    modal.find_element(:id, "digital_record_children_children__0__title_")
  end

  it "can review error messages on an invalid entry" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".modal-footer .btn-primary").click

    # general message at the top
    modal.find_element_with_text('//div[contains(@class, "alert-danger")]', /1 row\(s\) with an error \- click a row field to view the errors for that row/)

    # simulate focusing the row (normally done when the user focuses on an :input within the row)
    @driver.execute_script("$('#digital_record_children_children__0__title_').closest('tr').addClass('last-focused')")
    @driver.find_element(:css, ".error-summary")
    modal.find_element_with_text('//div[contains(@class, "error")]', /Date - you must provide a Label, Title or Date/)
    modal.find_element_with_text('//div[contains(@class, "error")]', /Title - you must provide a Label, Title or Date/)
    modal.find_element_with_text('//div[contains(@class, "error")]', /Label - you must provide a Label, Title or Date/)

    modal.find_element(:id, "digital_record_children_children__0__dates__0__date_type_").select_option("single")
    modal.find_element(:css, ".modal-footer .btn-primary").click

    # make sure this form post is done.. then continue..
    @driver.wait_for_ajax

    # general message at the top
    modal.find_element_with_text('//div[contains(@class, "alert-danger")]', /1 row\(s\) with an error \- click a row field to view the errors for that row/)

    # simulate focusing the row (normally done when the user focuses on an :input within the row)
    @driver.execute_script("$('#digital_record_children_children__0__title_').closest('tr').addClass('last-focused')")
    @driver.find_element(:css, ".error-summary")
    modal.find_element_with_text('//div[contains(@class, "error")]', /Expression \- is required unless a begin or end date is given/)
    modal.find_element_with_text('//div[contains(@class, "error")]', /Begin \- is required unless an expression or an end date is given/)
    modal.find_element_with_text('//div[contains(@class, "error")]', /End \- is required unless an expression or a begin date is given/)
  end

  it "can add a child via the RDE form" do
    @driver.clear_and_send_keys([:id, "digital_record_children_children__0__title_"], "My DO")
    @driver.execute_script("$('#digital_record_children_children__0__dates__0__label_').val('')")
    @driver.execute_script("$('#digital_record_children_children__0__dates__0__date_type_').val('')")

    @driver.click_and_wait_until_gone(:css => ".modal-footer .btn-primary")

    @driver.wait_for_ajax

    assert(5) {
      @driver.find_element_with_text("//div[@id='archives_tree']//li//span", /My DO/)
    }
  end

  it "can access the RDE form when editing an digital object" do
    @driver.find_element(:css, "#archives_tree_toolbar .btn-next-tree-node").click
    @driver.wait_for_ajax

    @driver.find_element(:id, "digital_object_component_title_")

    @driver.find_element(:link, "Rapid Data Entry").click
    @driver.find_element(:id => "rapidDataEntryModal")
  end


  it "can add multiple children and sticky columns stick" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    @driver.clear_and_send_keys([:id, "digital_record_children_children__0__title_"], "Child 1")
    modal.find_element(:css, ".btn.add-row").click

    modal.find_element(:id, "digital_record_children_children__1__title_").attribute("value").should eq("Child 1")

    @driver.clear_and_send_keys([:id, "digital_record_children_children__1__title_"], "Child 2")

    @driver.click_and_wait_until_gone(:css => ".modal-footer .btn-primary")
    @driver.wait_for_ajax

    assert(5) {
      @driver.find_element_with_text("//div[@id='archives_tree']//li//span", /Child 1/)
      @driver.find_element_with_text("//div[@id='archives_tree']//li//span", /Child 2/)
    }
  end

  it "can add multiple rows in one action" do
    @driver.find_element(:link, "Rapid Data Entry").click
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    @driver.clear_and_send_keys([:id, "digital_record_children_children__0__label_"], "DO_LABEL")

    modal.find_element(:css, ".btn.add-rows-dropdown").click

    # 8.times { modal.find_element(:css, ".add-rows-form input").send_keys(:arrow_up) }
    @driver.clear_and_send_keys([:css, ".add-rows-form input"], "9")

    # this is stupid, but seems to be a flakey issue with Selenium,
    # especailly when headless. The key is not being sent, so we'll try the
    # up arror method to add the rows.
    stupid = modal.find_element(:css, ".add-rows-form input").attribute('value')
    unless stupid == '9'
      9.times { modal.find_element(:css, ".add-rows-form input").send_keys(:arrow_up) }
    end

    modal.find_element(:css, ".add-rows-form .btn.btn-primary").click

    # there should be 10 rows now :)
    modal.find_elements(:css, "table tbody tr").length.should eq(10)

    # all should have level "DO_LABEL"
    modal.find_element(:id, "digital_record_children_children__1__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__2__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__3__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__4__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__5__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__6__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__7__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__8__label_").attribute("value").should eq("DO_LABEL")
    modal.find_element(:id, "digital_record_children_children__9__label_").attribute("value").should eq("DO_LABEL")
  end

  it "can perform a basic fill" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".btn.fill-column").click
    modal.find_element(:id, "basicFillTargetColumn").select_option("colLabel")
    @driver.clear_and_send_keys([:id, "basicFillValue"], "NEW_LABEL")
    @driver.click_and_wait_until_gone(:css, "#fill_basic .btn-primary")

    # all should have item as the level
    assert {
      modal.find_element(:id, "digital_record_children_children__0__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__1__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__2__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__3__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__4__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__5__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__6__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__7__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__8__label_").attribute("value").should eq("NEW_LABEL")
      modal.find_element(:id, "digital_record_children_children__9__label_").attribute("value").should eq("NEW_LABEL")
    }
  end

  it "can perform a sequence fill" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".btn.fill-column").click
    modal.find_element(:link, "Sequence").click

    modal.find_element(:id, "sequenceFillTargetColumn").select_option("colTitle")
    @driver.clear_and_send_keys([:id, "sequenceFillPrefix"], "ABC")
    @driver.clear_and_send_keys([:id, "sequenceFillFrom"], "1")
    @driver.clear_and_send_keys([:id, "sequenceFillTo"], "5")
    @driver.click_and_wait_until_gone(:css, "#fill_sequence .btn-primary")

    # message should be displayed "not enough in the sequence" or thereabouts..
    modal.find_element(:id, "sequenceTooSmallMsg")

    @driver.clear_and_send_keys([:id, "sequenceFillTo"], "10")
    @driver.click_and_wait_until_gone(:css, "#fill_sequence .btn-primary")

    @driver.wait_for_ajax

    # check the component id for each row matches the sequence
    modal.find_element(:id, "digital_record_children_children__0__title_").attribute("value").should eq("ABC1")
    modal.find_element(:id, "digital_record_children_children__1__title_").attribute("value").should eq("ABC2")
    modal.find_element(:id, "digital_record_children_children__2__title_").attribute("value").should eq("ABC3")
    modal.find_element(:id, "digital_record_children_children__3__title_").attribute("value").should eq("ABC4")
    modal.find_element(:id, "digital_record_children_children__4__title_").attribute("value").should eq("ABC5")
    modal.find_element(:id, "digital_record_children_children__5__title_").attribute("value").should eq("ABC6")
    modal.find_element(:id, "digital_record_children_children__6__title_").attribute("value").should eq("ABC7")
    modal.find_element(:id, "digital_record_children_children__7__title_").attribute("value").should eq("ABC8")
    modal.find_element(:id, "digital_record_children_children__8__title_").attribute("value").should eq("ABC9")
    modal.find_element(:id, "digital_record_children_children__9__title_").attribute("value").should eq("ABC10")

  end

  it "can perform a column reorder" do
    modal = @driver.find_element(:id => "rapidDataEntryModal")

    modal.find_element(:css, ".btn.reorder-columns").click

    # move Note Type 1 to the first position
    modal.find_element(:id, "columnOrder").select_option("colNType1")
    26.times { modal.find_element(:id, "columnOrderUp").click }

    # move Instance Type to the second position
    modal.find_element(:id, "columnOrder").select_option("colNType1") # deselect Note Type 1
    modal.find_element(:id, "columnOrder").select_option("colFUri")
    16.times { modal.find_element(:id, "columnOrderUp").click }

    # apply the new order
    @driver.click_and_wait_until_gone(:css, "#columnReorderForm .btn-primary")

    # check the first few headers now match the new order
    cells = modal.find_elements(:css, "table .fieldset-labels th")
    cells[1].attribute("id").should eq("colNType1")
    cells[2].attribute("id").should eq("colFUri")
    cells[3].attribute("id").should eq("colLabel")

    # check the section headers are correct
    cells = modal.find_elements(:css, "table .sections th")
    cells[1].text.should eq("Notes")
    cells[1].attribute("colspan").should eq("1")
    cells[2].text.should eq("File Version")
    cells[2].attribute("colspan").should eq("1")
    cells[3].text.should eq("Basic Information")
    cells[3].attribute("colspan").should eq("5")

    # check the form fields match the headers
    cells = modal.find_elements(:css, "table tbody tr:first-child td")
    cells[1].find_element(:id, "digital_record_children_children__0__notes__0__type_")
    cells[2].find_element(:id, "digital_record_children_children__0__file_versions__0__file_uri_")
    cells[3].find_element(:id, "digital_record_children_children__0__label_")
  end

end