require 'test_helper'

module ActiveModel
  class Serializer
    class FieldsetTest < ActiveModel::TestCase
      def setup
        params = ActionController::Parameters.new({fields: [:name] })
        params = ActiveModel::Serializer::ParamsAdapter.new(params)
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
        @association = JsonApi::PostSerializer._associations[:comments]
        @old_association = @association.dup
        @association.embed = :ids
        @association.embed_in_root = true
        
        params = ActionController::Parameters.new({include: ['comments'] })
        params = ActiveModel::Serializer::ParamsAdapter.new(params)
        
        @post = Post.new({ title: 'Title 1', body: 'Body 1', date: '1/1/2000' })
        @post_serializer = JsonApi::PostSerializer.new(@post, {params: params})
      end

      def teardown
        JsonApi::PostSerializer._associations[:comments] = @old_association
      end

      def test_filtered_associations_serialization
        comment_ids = @post.comments.map { |c| c.object_id }

        assert_equal({
          'post' => { id: @post.object_id, title: 'Title 1', body: 'Body 1', 'comment_ids' => comment_ids},
          comments: [{ id: comment_ids[0], content: 'C1' }, { id: comment_ids[1], content: 'C2' }]
        }, @post_serializer.as_json)
      end
      
    end

  end
end
