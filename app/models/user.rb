class User < ActiveRecord::Base
  has_many :stories,
    :include => :user
  has_many :comments
  has_many :authored_messages,
    :class_name => "Message",
    :foreign_key => "author_user_id"
  has_many :received_messages,
    :class_name => "Message",
    :foreign_key => "recipient_user_id"
  has_many :tag_filters

  has_secure_password

  validates_format_of :username, :with => /\A[A-Za-z0-9][A-Za-z0-9_-]*\Z/
  validates_uniqueness_of :username, :case_sensitive => false

  validates_format_of :email, :with => /\A[^@]+@[^@]+\.[^@]+\Z/
  validates_uniqueness_of :email, :case_sensitive => false

  validates_presence_of :password, :on => :create

  attr_accessible :username, :email, :password, :password_confirmation,
    :about, :email_replies, :pushover_replies, :pushover_user_key,
    :pushover_device, :email_messages, :pushover_messages

  before_save :check_session_token

  def check_session_token
    if self.session_token.blank?
      self.session_token = Utils.random_str(60)
    end
  end

  def unread_message_count
    Keystore.value_for("user:#{self.id}:unread_messages").to_i
  end

  def update_unread_message_count!
    Keystore.put("user:#{self.id}:unread_messages",
      Message.where(:recipient_user_id => self.id,
        :has_been_read => false).count)
  end

  def karma
    Keystore.value_for("user:#{self.id}:karma").to_i
  end

  def stories_submitted_count
    Keystore.value_for("user:#{self.id}:stories_submitted").to_i
  end
  
  def comments_posted_count
    Keystore.value_for("user:#{self.id}:comments_posted").to_i
  end

  def undeleted_received_messages
    received_messages.where([ "((recipient_user_id = ? AND " <<
      "deleted_by_recipient = 0) OR (author_user_id = ? AND " <<
      "deleted_by_author = 0))", self.id, self.id ])
  end

  def initiate_password_reset_for_ip(ip)
    self.password_reset_token = Utils.random_str(40)
    self.save!

    PasswordReset.password_reset_link(self, ip).deliver
  end

  def linkified_about
    Markdowner.to_html(self.about)
  end

  def recent_threads(amount)
    Comment.connection.select_all("SELECT DISTINCT " +
      "thread_id FROM comments WHERE user_id = #{q(self.id)} ORDER BY " +
      "created_at DESC LIMIT #{q(amount)}").map{|r| r.values.first }
  end
end
