# encoding: utf-8
# frozen_string_literal: true
#
# Redmine plugin for Document Management System "Features"
#
# Copyright © 2012    Daniel Munn <dan.munn@munnster.co.uk>
# Copyright © 2011-20 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../../test_helper', __FILE__)

class DmsfWebdavHeadTest < RedmineDmsf::Test::IntegrationTest

  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, 
    :enabled_modules, :dmsf_folders

  def setup  
    @admin = credentials 'admin'
    @jsmith = credentials 'jsmith'
    @project1 = Project.find 1
    @project1.enable_module!('dmsf')
    @project2 = Project.find 2
    @dmsf_webdav = Setting.plugin_redmine_dmsf['dmsf_webdav']
    Setting.plugin_redmine_dmsf['dmsf_webdav'] = true
    @dmsf_webdav_strategy = Setting.plugin_redmine_dmsf['dmsf_webdav_strategy']
    Setting.plugin_redmine_dmsf['dmsf_webdav_strategy'] = 'WEBDAV_READ_WRITE'
    @dmsf_webdav_use_project_names = Setting.plugin_redmine_dmsf['dmsf_webdav_strategy']
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = true
    @project1_uri = Addressable::URI.escape(RedmineDmsf::Webdav::ProjectResource.create_project_name(@project1))
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = false
    @dmsf_storage_directory = Setting.plugin_redmine_dmsf['dmsf_storage_directory']
    Setting.plugin_redmine_dmsf['dmsf_storage_directory'] = 'files/dmsf'
    FileUtils.cp_r File.join(File.expand_path('../../../fixtures/files', __FILE__), '.'), DmsfFile.storage_path
    User.current = nil    
  end

  def teardown
    # Delete our tmp folder
    begin
      FileUtils.rm_rf DmsfFile.storage_path
    rescue => e
      error e.message
    end
    Setting.plugin_redmine_dmsf['dmsf_webdav'] = @dmsf_webdav
    Setting.plugin_redmine_dmsf['dmsf_webdav_strategy'] = @dmsf_webdav_strategy
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = @dmsf_webdav_use_project_names
    Setting.plugin_redmine_dmsf['dmsf_storage_directory'] = @dmsf_storage_directory
  end
  
  def test_truth
    assert_kind_of Project, @project1
    assert_kind_of Project, @project2
  end

  def test_head_requires_authentication
    head "/dmsf/webdav/#{@project1.identifier}"
    assert_response :unauthorized
    check_headers_dont_exist
  end

  def test_head_responds_with_authentication
    head "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @admin
    assert_response :success
    check_headers_exist
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = true
    head "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @admin
    assert_response :not_found
    head "/dmsf/webdav/#{@project1_uri}", params: nil, headers: @admin
    assert_response :success
  end

  # Note:
  #   At present we use Rack to serve the file, this makes life easy however it removes the Etag
  #   header and invalidates the test - where as a folder listing will always not include a last-modified
  #   (but may include an etag, so there is an allowance for a 1 in 2 failure rate on (optionally) required
  #   headers)
  def test_head_responds_to_file
    head "/dmsf/webdav/#{@project1.identifier}/test.txt", params: nil, headers: @admin
    assert_response :success
    check_headers_exist # Note it'll allow 1 out of the 3 expected to fail
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = true
    head "/dmsf/webdav/#{@project1.identifier}/test.txt", params: nil, headers: @admin
    assert_response :not_found
    head "/dmsf/webdav/#{@project1_uri}/test.txt", params: nil, headers: @admin
    assert_response :success
  end

  def test_head_responds_to_file_anonymous_other_user_agent
    head "/dmsf/webdav/#{@project1.identifier}/test.txt", params: nil, headers: { HTTP_USER_AGENT: 'Other' }
    assert_response :unauthorized
    check_headers_dont_exist
  end

  def test_head_fails_when_file_not_found
    head "/dmsf/webdav/#{@project1.identifier}/not_here.txt", params: nil, headers: @admin
    assert_response :not_found
    check_headers_dont_exist
  end

  def test_head_fails_when_file_not_found_anonymous_other_user_agent
    head "/dmsf/webdav/#{@project1.identifier}/not_here.txt", params: nil, headers: { HTTP_USER_AGENT: 'Other' }
    assert_response :unauthorized
    check_headers_dont_exist
  end

  def test_head_fails_when_folder_not_found
    head '/dmsf/webdav/folder_not_here', params: nil, headers: @admin
    assert_response :not_found
    check_headers_dont_exist
  end

  def test_head_fails_when_folder_not_found_anonymous_other_user_agent
    head '/dmsf/webdav/folder_not_here', params: nil, headers: { HTTP_USER_AGENT: 'Other' }
    assert_response :unauthorized
    check_headers_dont_exist
  end

  def test_head_fails_when_project_is_not_enabled_for_dmsf
    head "/dmsf/webdav/#{@project2.identifier}/test.txt", params: nil, headers: @jsmith
    assert_response :not_found
    check_headers_dont_exist
  end

  private

  def check_headers_exist
    assert !(response.headers.nil? || response.headers.empty?),
      'Head returned without headers' # Headers exist?
    values = {}
    values[:etag] = { optional: true, content: response.headers['Etag'] }
    values[:content_type] = response.headers['Content-Type']
    values[:last_modified] = { optional: true, content: response.headers['Last-Modified'] }
    single_optional = false
    values.each do |key,val|
      if val.is_a?(Hash)
        if val[:optional].nil? || !val[:optional]
           assert(!(val[:content].nil? || val[:content].empty?), "Expected header #{key} was empty." ) if single_optional
        else
          single_optional = true
        end
      else
        assert !(val.nil? || val.empty?), "Expected header #{key} was empty."
      end
    end
  end

  def check_headers_dont_exist
    assert !(response.headers.nil? || response.headers.empty?), 'Head returned without headers' # Headers exist?
    values = {}
    values[:etag] = response.headers['Etag']
    values[:last_modified] = response.headers['Last-Modified']
    values.each do |key,val|
      assert (val.nil? || val.empty?), "Expected header #{key} should be empty."
    end
  end

end
