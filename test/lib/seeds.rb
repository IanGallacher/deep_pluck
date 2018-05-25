ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users, :force => true do |t|
    t.string :name
    t.string :email
    t.string :gender
    t.text :serialized_attribute
  end
  create_table :posts, :force => true do |t|
    t.integer :user_id
    t.string :name
    t.string :title
  end
  create_table :post_comments, :force => true do |t|
    t.integer :post_id
    t.string :comment
  end
  create_table :contacts, :force => true do |t|
    t.integer :user_id
    t.string :address
    t.string :phone_number
  end
  create_table :contact2s, :id => false, :force => true do |t|
    t.primary_key :id2
    t.integer :user_id2
    t.string :address
    t.string :phone_number
  end
  create_table :contact2_infos, :id => false, :force => true do |t|
    t.primary_key :id2
    t.string :info
    t.integer :contact_id2
  end
  create_table :user_achievements, :force => true do |t|
    t.references :user, index: true
    t.references :achievement, index: true
  end
  create_table :achievements, :force => true do |t|
    t.string :name
  end
  create_table :notes, :force => true do |t|
    t.integer :parent_id
    t.string :parent_type
    t.string :content
  end
end

ActiveSupport::Dependencies.autoload_paths << File.expand_path('../models/', __FILE__)

class User < ActiveRecord::Base
  serialize :serialized_attribute, Hash
  has_many :posts
  if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.0.0')
    has_many :posts_1_3, :conditions => ['title LIKE ? OR title LIKE ? ', '%post1', '%post3'], :class_name => "Post"
  else
    has_many :posts_1_3, -> { where('title LIKE ? OR title LIKE ? ', '%post1', '%post3') }, :class_name => "Post"
  end
  has_one :contact
  has_one :contact2, :foreign_key => :user_id2
  has_many :notes, as: :parent
  has_many :user_achievements
  has_many :achievements, :through => :user_achievements
  has_and_belongs_to_many :achievements2, class_name: 'Achievement', :join_table => :user_achievements
end
class Post < ActiveRecord::Base
  belongs_to :user
  has_many :post_comments
  has_many :notes, as: :parent
end
class PostComment < ActiveRecord::Base
  belongs_to :post
end
class Contact < ActiveRecord::Base
  belongs_to :user
  has_one :note, as: :parent
end
class Contact2 < ActiveRecord::Base
  self.primary_key = :id2
  belongs_to :user, :foreign_key => :user_id2
  has_one :contact2_info, :foreign_key => :contact_id2
end
class Contact2Info < ActiveRecord::Base
  self.primary_key = :id2
  belongs_to :contact2, :foreign_key => :id2
end
class UserAchievement < ActiveRecord::Base
  belongs_to :user
  belongs_to :achievement
end

class Achievement < ActiveRecord::Base
  has_many :user_achievements
  has_many :users, :through => :user_achievements
  if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.0.0')
    has_many :female_users, :conditions => {:gender => 'female'}, :through => :user_achievements, :foreign_key => "user_id", :source => :user
  else
    has_many :female_users, ->{ where(:gender => 'female')}, :through => :user_achievements, :foreign_key => "user_id", :source => :user
  end
  has_and_belongs_to_many :users2, class_name: 'User', :join_table => :user_achievements
end

class Note < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
end

users = User.create([
  {:name => 'John', :email => 'john@example.com', :gender => 'male'},
  {:name => 'Pearl', :email => 'pearl@example.com', :gender => 'female', :serialized_attribute => {:testing => true, :deep => {:deep => :deep}}},
  {:name => 'Kathenrie', :email => 'kathenrie@example.com', :gender => 'female'},
])
posts = Post.create([
  {:name => 'post1', :title => "John's post1", :user_id => users[0].id},
  {:name => 'post2', :title => "John's post2", :user_id => users[0].id},
  {:name => 'post3', :title => "John's post3", :user_id => users[0].id},
  {:name => 'post4', :title => "Pearl's post1", :user_id => users[1].id},
  {:name => 'post5', :title => "Pearl's post2", :user_id => users[1].id},
  {:name => 'post6', :title => "Kathenrie's post1", :user_id => users[2].id},
])
PostComment.create([
  {:post_id => posts[2].id, :comment => "WTF?"},
  {:post_id => posts[2].id, :comment => "..."},
  {:post_id => posts[3].id, :comment => "cool!"},
  {:post_id => posts[5].id, :comment => "hahahahahahha"},
])
contacts = Contact.create([
  {:address => "John's Home", :phone_number => "0911666888", :user_id => users[0].id},
  {:address => "Pearl's Home", :phone_number => "1011-0404-934", :user_id => users[1].id},
  {:address => "Kathenrie's Home", :phone_number => "02-254421", :user_id => users[2].id},
])
contact2 = Contact2.create([
  {:address => "John's Home2", :phone_number => "0911666888", :user_id2 => users[0].id},
  {:address => "Pearl's Home2", :phone_number => "1011-0404-934", :user_id2 => users[1].id},
  {:address => "Kathenrie's Home2", :phone_number => "02-254421", :user_id2 => users[2].id},
])
Contact2Info.create([
  {:info => "info1", :contact_id2 => contact2[0].id},
  {:info => "info2", :contact_id2 => contact2[1].id},
  {:info => "info3", :contact_id2 => contact2[2].id},
])
achievements = Achievement.create([
  {:name => 'achievement1'},
  {:name => 'achievement2'},
  {:name => 'achievement3'},
])
UserAchievement.create([
  {:user_id => users[0].id, :achievement_id => achievements[0].id},
  {:user_id => users[1].id, :achievement_id => achievements[0].id},
  {:user_id => users[1].id, :achievement_id => achievements[2].id},
])
Note.create([
  {parent: users[0], content: "user note"},
  {parent: contacts[0], content: "contact note"},
  {parent: posts[0], content: "post note"}
])
