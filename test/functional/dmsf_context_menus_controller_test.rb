# encoding: utf-8
# frozen_string_literal: true
#
# Redmine plugin for Document Management System "Features"
#
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

require File.expand_path('../../test_helper', __FILE__)

class DmsfContextMenusControllerTest < RedmineDmsf::Test::TestCase
  include Redmine::I18n  
    
  fixtures :users, :email_addresses, :projects, :members, :roles, :member_roles, :dmsf_folders,
           :dmsf_files, :dmsf_file_revisions, :dmsf_links

  def setup
    @user_member = User.find 2 # John Smith - manager
    @user_member3 = User.find 3 # Foo
    @project1 = Project.find 1
    @project1.enable_module! :dmsf
    @file1 = DmsfFile.find 1
    @folder1 = DmsfFolder.find 1
    @folder5 = DmsfFolder.find 5
    @file_link2 = DmsfLink.find 2
    @file_link6 = DmsfLink.find 6
    @folder_link1 = DmsfLink.find 1
    @url_link5 = DmsfLink.find 5
    User.current = nil
    @request.session[:user_id] = @user_member.id
    @role1 = Role.find 1 # Manager
  end
  
  def test_truth
    assert_kind_of User, @user_member
    assert_kind_of User, @user_member3
    assert_kind_of Project, @project1
    assert_kind_of DmsfFile, @file1
    assert_kind_of DmsfFolder, @folder1
    assert_kind_of DmsfFolder, @folder5
    assert_kind_of DmsfLink, @file_link2
    assert_kind_of DmsfLink, @file_link6
    assert_kind_of DmsfLink, @folder_link1
    assert_kind_of DmsfLink, @url_link5
    assert_kind_of Role, @role1
  end

  def test_dmsf_file
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit', text: l(:button_edit)
    assert_select 'a.icon-lock', text: l(:button_lock)
    assert_select 'a.icon-email-add', text: l(:label_notifications_on)
    assert_select 'a.icon-del', text: l(:button_delete)
    assert_select 'a.icon-download', text: l(:button_download)
    assert_select 'a.icon-email', text: l(:field_mail)
    assert_select 'a.icon-file', text: l(:button_edit_content)
  end

  def test_dmsf_file_locked
    @file1.lock!
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit.disabled', text: l(:button_edit)
    assert_select 'a.icon-unlock', text: l(:button_unlock)
    assert_select 'a.icon-lock', text: l(:button_lock), count: 0
    assert_select 'a.icon-email-add.disabled', text: l(:label_notifications_on)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_file_locked_force_unlock_permission_off
    l = @file1.lock!
    l.user = @user_member3
    l.save
    @role1.remove_permission! :force_file_unlock
    @role1.add_permission! :file_manipulation
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-unlock.disabled', text: l(:button_unlock)
  end

  def test_dmsf_file_locked_force_unlock_permission_on
    l = @file1.lock!
    l.user = @user_member3
    l.save
    @role1.add_permission! :force_file_unlock
    @role1.add_permission! :file_manipulation
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-unlock.disabled', text: l(:button_unlock), count: 0
  end

  def test_dmsf_file_notification_on
    @file1.notify_activate
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-email', text: l(:label_notifications_off)
    assert_select 'a.icon-email-add', text: l(:label_notifications_on), count: 0
  end

  def test_dmsf_file_manipulation_permission_off
    @role1.remove_permission! :file_manipulation
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit.disabled', text: l(:button_edit)
    assert_select 'a.icon-lock.disabled', text: l(:button_lock)
    assert_select 'a.icon-email-add.disabled', text: l(:label_notifications_on)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_file_manipulation_permission_on
    @role1.add_permission! :file_manipulation
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a:not(icon-edit.disabled)', text: l(:button_edit)
    assert_select 'a:not(icon-lock.disabled)', text: l(:button_lock)
    assert_select 'a:not(icon-email-add.disabled)', text: l(:label_notifications_on)
    assert_select 'a:not(icon-del.disabled)', text: l(:button_delete)
  end

  def test_dmsf_file_email_permission_off
    @role1.remove_permission! :email_document
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-email.disabled', text: l(:field_mail)
  end

  def test_dmsf_file_email_permission_on
    @role1.remove_permission! :email_document
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a:not(icon-email.disabled)', text: l(:field_mail)
  end

  def test_dmsf_file_delete_permission_off
    @role1.remove_permission! :file_delete
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_file_delete_permission_on
    @role1.remove_permission! :file_delete
    get :dmsf, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a:not(icon-del.disabled)', text: l(:button_delete)
    assert_select 'a.icon-del', text: l(:button_delete)
  end

  def test_dmsf_file_link
    get :dmsf, params: {
        id: @file_link6.project.id, folder_id: @file_link6.dmsf_folder, ids: ["file-link-#{@file_link6.id}"] }
    assert_response :success
    assert_select 'a.icon-edit', text: l(:button_edit)
    assert_select 'a.icon-lock', text: l(:button_lock)
    assert_select 'a.icon-email-add', text: l(:label_notifications_on)
    assert_select 'a.icon-del', text: l(:button_delete)
    assert_select 'a.icon-download', text: l(:button_download)
    assert_select 'a.icon-email', text: l(:field_mail)
    assert_select 'a.icon-file', text: l(:button_edit_content)
  end

  def test_dmsf_file_link_locked
    assert @file_link2.target_file.locked?
    get :dmsf, params: {
        id: @file_link2.project.id, folder_id: @file_link2.dmsf_folder.id, ids: ["file-link-#{@file_link2.id}"] }
    assert_response :success
    assert_select 'a.icon-edit.disabled', text: l(:button_edit)
    assert_select 'a.icon-unlock', text: l(:button_unlock)
    assert_select 'a.icon-lock', text: l(:button_lock), count: 0
    assert_select 'a.icon-email-add.disabled', text: l(:label_notifications_on)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_url_link
    get :dmsf, params: { id: @url_link5.project.id, ids: ["url-link-#{@url_link5.id}"] }
    assert_response :success
    assert_select 'a.icon-del', text: l(:button_delete)
  end

  def test_dmsf_folder
    get :dmsf, params: { id: @folder1.project.id, ids: ["folder-#{@folder1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit', text: l(:button_edit)
    assert_select 'a.icon-lock', text: l(:button_lock)
    assert_select 'a.icon-email-add', text: l(:label_notifications_on)
    assert_select 'a.icon-del', text: l(:button_delete)
    assert_select 'a:not(icon-del.disabled)', text: l(:button_delete)
    assert_select 'a.icon-download', text: l(:button_download)
    assert_select 'a.icon-email', text: l(:field_mail)
  end

  def test_dmsf_folder_not_empty
    get :dmsf, params: { id: @folder1.project.id, ids: ["folder-#{@folder1.id}"] }
    assert_response :success
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_folder_locked
    assert @folder5.locked?
    get :dmsf, params: { id: @folder5.project.id, ids: ["folder-#{@folder5.id}"] }
    assert_response :success
    assert_select 'a.icon-edit.disabled', text: l(:button_edit)
    assert_select 'a.icon-unlock', text: l(:button_unlock)
    assert_select 'a.icon-lock', text: l(:button_lock), count: 0
    assert_select 'a.icon-email-add.disabled', text: l(:label_notifications_on)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_folder_notification_on
    @folder5.notify_activate
    get :dmsf, params: { id: @folder5.project.id, ids: ["folder-#{@folder5.id}"] }
    assert_response :success
    assert_select 'a.icon-email', text: l(:label_notifications_off)
    assert_select 'a.icon-email-add', text: l(:label_notifications_on), count: 0
  end

  def test_dmsf_folder_manipulation_permmissions_off
    @role1.remove_permission! :folder_manipulation
    get :dmsf, params: { id: @folder1.project.id, ids: ["folder-#{@folder1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit.disabled', text: l(:button_edit)
    assert_select 'a.icon-lock.disabled', text: l(:button_lock)
    assert_select 'a.icon-email-add.disabled', text: l(:label_notifications_on)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_folder_manipulation_permmissions_on
    @role1.add_permission! :folder_manipulation
    #assert !@folder5.locked?
    get :dmsf, params: { id: @folder1.project.id, ids: ["folder-#{@folder1.id}"] }
    assert_response :success
    assert_select 'a:not(icon-edit.disabled)', text: l(:button_edit)
    assert_select 'a:not(icon-lock.disabled)', text: l(:button_lock)
    assert_select 'a:not(icon-email-add.disabled)', text: l(:label_notifications_on)
    assert_select 'a:not(icon-del.disabled)', text: l(:button_delete)
  end

  def test_dmsf_folder_email_permmissions_off
    @role1.remove_permission! :email_documents
    get :dmsf, params: { id: @folder5.project.id, ids: ["folder-#{@folder5.id}"] }
    assert_response :success
    assert_select 'a.icon-email.disabled', text: l(:field_mail)
  end

  def test_dmsf_folder_email_permmissions_on
    @role1.add_permission! :email_documents
    get :dmsf, params: { id: @folder5.project.id, ids: ["folder-#{@folder5.id}"] }
    assert_response :success
    assert_select 'a:not(icon-email.disabled)', text: l(:field_mail)
  end

  def test_dmsf_folder_link
    get :dmsf, params: { id: @folder_link1.project.id, ids: ["folder-#{@folder_link1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit', text: l(:button_edit)
    assert_select 'a.icon-lock', text: l(:button_lock)
    assert_select 'a.icon-email-add', text: l(:label_notifications_on)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
    assert_select 'a.icon-download', text: l(:button_download)
    assert_select 'a.icon-email', text: l(:field_mail)
  end

  def test_dmsf_folder_link_locked
    @folder_link1.target_folder.lock!
    get :dmsf, params: { id: @folder_link1.project.id, ids: ["folder-#{@folder_link1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit.disabled', text: l(:button_edit)
    assert_select 'a.icon-unlock', text: l(:button_unlock)
    assert_select 'a.icon-lock', text: l(:button_lock), count: 0
    assert_select 'a.icon-email-add.disabled', text: l(:label_notifications_on)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_dmsf_multiple
    get :dmsf, params: { id: @project1.id, ids: ["folder-#{@folder1.id}", "file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-edit', text: l(:button_edit), count: 0
    assert_select 'a.icon-unlock', text: l(:button_unlock), count: 0
    assert_select 'a.icon-lock', text: l(:button_lock), count: 0
    assert_select 'a.icon-email-add', text: l(:label_notifications_on), count: 0
    assert_select 'a.icon-email', text: l(:label_notifications_off), count: 0
    assert_select 'a.icon-del', text: l(:button_delete)
    assert_select 'a.icon-download', text: l(:button_download)
    assert_select 'a.icon-email', text: l(:field_mail)
  end

  def test_trash_file
    get :trash, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-cancel', text: l(:title_restore)
    assert_select 'a.icon-del', text: l(:button_delete)
  end

  def test_trash_file_manipulation_permissions_off
    @role1.remove_permission! :file_manipulation
    get :trash, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-cancel.disabled', text: l(:title_restore)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_trash_file_manipulation_permissions_on
    @role1.add_permission! :file_manipulation
    get :trash, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a:not(icon-cancel.disabled)', text: l(:title_restore)
    assert_select 'a:not(icon-del.disabled)', text: l(:button_delete)
  end

  def test_trash_file_delete_permissions_off
    @role1.remove_permission! :file_delete
    get :trash, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_trash_file_delete_permissions_on
    @role1.add_permission! :file_delete
    get :trash, params: { id: @file1.project.id, ids: ["file-#{@file1.id}"] }
    assert_response :success
    assert_select 'a:not(icon-del.disabled)', text: l(:button_delete)
  end

  def test_trash_folder
    get :trash, params: { id: @folder5.project.id, ids: ["folder-#{@folder5.id}"] }
    assert_response :success
    assert_select 'a.icon-cancel', text: l(:title_restore)
    assert_select 'a.icon-del', text: l(:button_delete)
  end

  def test_trash_folder_manipulation_permissions_off
    @role1.remove_permission! :folder_manipulation
    get :trash, params: { id: @folder1.project.id, ids: ["folder-#{@folder1.id}"] }
    assert_response :success
    assert_select 'a.icon-cancel.disabled', text: l(:title_restore)
    assert_select 'a.icon-del.disabled', text: l(:button_delete)
  end

  def test_trash_folder_manipulation_permissions_on
    @role1.add_permission! :folder_manipulation
    get :trash, params: { id: @folder1.project.id, ids: ["folder-#{@folder1.id}"] }
    assert_response :success
    assert_select 'a:not(icon-cancel.disabled)', text: l(:title_restore)
    assert_select 'a:not(icon-del.disabled)', text: l(:button_delete)
  end

  def test_trash_multiple
    get :trash, params: { id: @project1.id, ids: ["file-#{@file1.id}", "folder-#{@folder1.id}"] }
    assert_response :success
    assert_select 'a.icon-cancel', text: l(:title_restore)
    assert_select 'a.icon-del', text: l(:button_delete)
  end

end