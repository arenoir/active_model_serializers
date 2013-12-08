require 'test_helper'

module ActiveModel
  class Serializer
    class FieldsetTest < ActiveModel::TestCase
      def setup
        params = ActionController::Parameters.new({fields: [:name] })
        params = ActiveModel::Serializer::ParamsAdapter.new(params, 'profile')
        @profile = Profile.new({ name: 'Name 1', description: 'Description 1', comments: 'Comments 1' })
        @profile_serializer = ProfileSerializer.new(@profile, {params: params})
      end

      def test_fieldset_filter_attributes_serialization
        assert_equal({
          'profile' => { name: 'Name 1' }
        }, @profile_serializer.as_json)
      end
    end

    class IncludesTest < ActiveModel::TestCase
      def setup
        @association = AuthorPostSerializer._associations[:comments]
        @old_association = @association.dup
        @association.embed = :ids
        @association.embed_in_root = true
        
        params = ActionController::Parameters.new({include: ['comments'] })
        params = ActiveModel::Serializer::ParamsAdapter.new(params, 'author_post')
        
        @post = Post.new({ title: 'Title 1', body: 'Body 1', date: '1/1/2000' })
        @post_serializer = AuthorPostSerializer.new(@post, {params: params})
      end

      def teardown
        PostSerializer._associations[:comments] = @old_association
      end

      def test_filtered_associations_serialization
        assert_equal({
          'author_post' => { title: 'Title 1', body: 'Body 1', 'comment_ids' => @post.comments.map { |c| c.object_id } },
          comments: [{ content: 'C1' }, { content: 'C2' }]
        }, @post_serializer.as_json)
      end
      
    end

  end
end
