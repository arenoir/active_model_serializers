require 'test_helper'

module ActionController
  module Serialization
    module FieldsetsSpec
      class ArraySerializerWithParamsTest < ActionController::TestCase
        def setup
          super
          @post_comments_assoc  = JsonApi::PostSerializer._associations[:comments]
          @_post_comments_assoc = @post_comments_assoc.dup
          
          @post_author_assoc  = JsonApi::PostSerializer._associations[:author]
          @_post_author_assoc = @post_author_assoc.dup

          @comment_author_assoc  = JsonApi::CommentSerializer._associations[:author]
          @_comment_author_assoc = @comment_author_assoc.dup

          @post_comments_assoc.embed = :ids
          @post_comments_assoc.embed_in_root = true

          @post_author_assoc.embed = :ids
          @post_author_assoc.embed_in_root = true

          @comment_author_assoc.embed = :ids
          @comment_author_assoc.embed_in_root = true

        end

        def teardown
          super
          JsonApi::PostSerializer._associations[:comments] = @_post_comments_assoc
          JsonApi::PostSerializer._associations[:author]   = @_post_author_assoc

          JsonApi::CommentSerializer._associations[:author] = @_comment_author_assoc
        end

        class MyController < ActionController::Base
          def initialize(*)
            super
            @post = Post.new({ title: 'Title1', body: 'Body1'})

          end
          attr_reader :post

          def index
            render json: [@post], each_serializer: JsonApi::PostSerializer
          end
        end

        tests MyController

        def test_render_array_with_single_fields_array

          get :index, fields: [:title]
          assert_equal 'application/json', @response.content_type

          comments = @controller.post.comments.map {|c| {author_id: c.author.object_id}}

          expected_output = <<-eos
            {"\my\":[
              {
                \"title\":\"Title1\",
                \"comment_ids\":#{@controller.post.comments.map { |c| c.object_id }},
                \"author_id\":#{@controller.post.author.object_id}
              }],
              \"authors\":[{}],
              \"comments\":#{comments.to_json}
            }
          eos

          expected_output.gsub!(/\s+/, "")

          assert_equal(expected_output, @response.body)

        end

        def test_render_array_with_fields_hash

          get :index, fields: {post: [:title], person: [:id]}

          comments = @controller.post.comments.map {|c| {author_id: c.author.object_id}}

          authors = @controller.post.comments.map(&:author) << @controller.post.author

          authors_json = authors.map {|a| {id: a.object_id} }.to_json

          expected_output = <<-eos
            {"\my\":[
              {
                \"title\":\"Title1\",
                \"comment_ids\":#{@controller.post.comments.map { |c| c.object_id }},
                \"author_id\":#{@controller.post.author.object_id}
              }],
              \"authors\":#{authors_json},
              \"comments\":#{comments.to_json}
            }
          eos

          expected_output.gsub!(/\s+/, "")

          assert_equal(expected_output, @response.body)

        end

        def test_render_array_with_include
          get :index, include: ['author']
          assert_equal 'application/json', @response.content_type

          expected_output = <<-eos
            {
              "\my\":[
                {
                  \"id\":#{@controller.post.object_id},
                  \"title\":\"Title1\",
                  \"body\":\"Body1\",
                  \"author_id\":#{@controller.post.author.object_id}
                }
              ],
              \"authors\":[
                {
                  \"id\":#{@controller.post.author.object_id},
                  \"name\":\"PU\",
                  \"email\":null
                }
              ]
            }
          eos

          expected_output.gsub!(/\s+/, "")

          assert_equal(expected_output, @response.body)

        end

        def test_render_array_with_nested_include
          get :index, include: ['comments.author']
          assert_equal 'application/json', @response.content_type

          expected_output = <<-eos
            {
              "\my\":[
                {
                  \"id\":#{@controller.post.object_id},
                  \"title\":\"Title1\",
                  \"body\":\"Body1\"
                }
              ],
              \"authors\":[
                {
                  \"id\":#{@controller.post.author.object_id},
                  \"name\":\"PU\",
                  \"email\":null
                }
              ]
            }
          eos

          expected_output.gsub!(/\s+/, "")

          assert_equal(expected_output, @response.body)
        end

      end
    end
  end
end