###
## Serializers
###

module JsonApi

  class PersonSerializer < ActiveModel::Serializer
    attributes :id, :name, :email
  end

  class CommentSerializer < ActiveModel::Serializer
    attributes :id, :content
    has_one :author, serializer: JsonApi::PersonSerializer
  end

  class PostSerializer < ActiveModel::Serializer
    attributes :id, :title, :body

    has_many :comments, serializer: JsonApi::CommentSerializer
    has_one :author, serializer: JsonApi::PersonSerializer
  end

end
