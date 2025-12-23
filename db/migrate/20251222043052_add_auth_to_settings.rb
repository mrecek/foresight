class AddAuthToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :auth_username, :string
    add_column :settings, :auth_password_digest, :string
  end
end
