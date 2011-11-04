require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Document do
  include Elastictastic::TestHelpers

  let(:last_request) { FakeWeb.last_request }
  let(:last_request_body) { JSON.parse(last_request.body) }

  describe '#save' do
    context 'new object' do
      let!(:id) { stub_elasticsearch_create('default', 'post') }
      let(:post) { Post.new }

      before do
        post.title = 'Hot Pasta'
        post.save
      end

      it 'should send POST request' do
        last_request.method.should == 'POST'
      end

      it 'should send to index/type path' do
        last_request.path.should == '/default/post'
      end

      it 'should send document in the body' do
        last_request.body.should == post.to_elasticsearch_doc.to_json
      end

      it 'should populate ID of model object' do
        post.id.should == id
      end

      it 'should mark object as persisted' do
        post.should be_persisted
      end
    end # context 'new object'

    context 'new object with ID' do
      let(:post) { Post.new.tap { |post| post.id = '123' }}

      context 'with unique id' do
        before do
          stub_elasticsearch_create('default', 'post', post.id)
          post.save
        end

        it 'should send PUT request' do
          last_request.method.should == 'PUT'
        end

        it 'should send request to _create verb for document resource' do
          last_request.path.should == "/default/post/123/_create"
        end

        it 'should send document in body' do
          last_request.body.should == post.to_elasticsearch_doc.to_json
        end
      end # context 'with unique ID'

      context 'with duplicate ID' do
        before do
          stub_elasticsearch_create(
            'default', 'post', '123',
            :body => {
              'error' => 'DocumentAlreadyExistsEngineException[[post][2] [post][1]]: document already exists',
              'status' => 409
            }.to_json
          )
        end

        let(:save) { lambda { post.save }}

        it 'should raise DocumentAlreadyExistsEngineException' do
          expect(&save).to raise_error(Elastictastic::ServerError::DocumentAlreadyExistsEngineException)
        end

        it 'should inject the error message into the exception' do
          expect(&save).to raise_error { |error|
            error.message.should == '[[post][2] [post][1]]: document already exists'
          }
        end

        it 'should inject the status into the exception' do
          expect(&save).to raise_error { |error|
            error.status.should == 409
          }
        end
      end # context 'with duplicate ID'
    end # context 'new object with ID'

    shared_examples_for 'persisted object' do
      describe 'identity attributes' do
        it 'should not allow setting of ID' do
          lambda { post.id = 'bogus' }.should raise_error(Elastictastic::IllegalModificationError)
        end
      end # describe 'identity attributes'

      describe '#save' do
        before do
          stub_elasticsearch_update('default', 'post', post.id)
          post.title = 'Fun Factories for Fickle Ferrets'
          post.save
        end

        it 'should send PUT request' do
          last_request.method.should == 'PUT'
        end

        it "should send to document's resource path" do
          last_request.path.should == "/default/post/#{post.id}"
        end

        it "should send document's body in request" do
          last_request.body.should == post.to_elasticsearch_doc.to_json
        end
      end # describe '#save'
    end # shared_examples_for 'persisted object'

    context 'object after save' do
      let(:post) do
        stub_elasticsearch_create('default', 'post')
        Post.new.tap { |post| post.save }
      end

      it_should_behave_like 'persisted object'
    end # context 'object after save'

    context 'existing persisted object' do
      let(:post) do
        Post.new.tap do |post|
          post.id = '123'
          post.persisted!
        end
      end

      it_should_behave_like 'persisted object'
    end # context 'existing persisted object'
  end # describe '#save'

  describe '#destroy' do
    context 'existing persisted object' do
      let(:post) do
        Post.new.tap do |post|
          post.id = '123'
          post.persisted!
        end
      end

      before do
        stub_elasticsearch_destroy('default', 'post', '123')
        @result = post.destroy
      end

      it 'should send DELETE request' do
        last_request.method.should == 'DELETE'
      end

      it 'should send request to document resource path' do
        last_request.path.should == '/default/post/123'
      end

      it 'should mark post as non-persisted' do
        post.should_not be_persisted
      end

      it 'should return true' do
        @result.should be_true
      end
    end # context 'existing persisted object'

    context 'transient object' do
      let(:post) { Post.new }

      it 'should raise OperationNotAllowed' do
        expect { post.destroy }.to raise_error(Elastictastic::OperationNotAllowed)
      end
    end # context 'transient object'

    context 'non-existent persisted object' do
      let(:post) do
        Post.new.tap do |post|
          post.id = '123'
          post.persisted!
        end
      end

      before do
        stub_elasticsearch_destroy(
          'default', 'post', '123',
          :body => {
            'ok' => true,
            'found' => false,
            '_index' => 'default',
            '_type' => 'post',
            '_id' => '123',
            '_version' => 0
          }.to_json
        )
        @result = post.destroy
      end

      it 'should return false' do
        @result.should be_false
      end
    end # describe 'non-existent persisted object'
  end # describe '#destroy'

  describe '::destroy_all' do
    describe 'with default index' do
      before do
        stub_elasticsearch_destroy_all('default', 'post')
        Post.destroy_all
      end

      it 'should send DELETE' do
        last_request.method.should == 'DELETE'
      end

      it 'should send to index/type path' do
        last_request.path.should == '/default/post'
      end
    end # describe 'with default index'

    describe 'with specified index' do
      before do
        stub_elasticsearch_destroy_all('my_index', 'post')
        Post.in_index('my_index').destroy_all
      end

      it 'should send to specified index' do
        last_request.path.should == '/my_index/post'
      end
    end # describe 'with specified index'
  end # describe '::destroy_all'

  describe '::sync_mapping' do
    shared_examples_for 'put mapping' do
      it 'should send PUT request' do
        last_request.method.should == 'PUT'
      end

      it 'should send mapping to ES' do
        last_request.body.should == Post.mapping.to_json
      end
    end # shared_examples_for 'put mapping'

    context 'with default index' do
      before do
        stub_elasticsearch_put_mapping('default', 'post')
        Post.sync_mapping
      end

      it 'should send to resource path for mapping' do
        last_request.path.should == '/default/post/_mapping'
      end

      it_should_behave_like 'put mapping'
    end # context 'with default index'

    context 'with specified index' do
      before do
        stub_elasticsearch_put_mapping('my_cool_index', 'post')
        Post.in_index('my_cool_index').sync_mapping
      end

      it 'should send to specified index resource path' do
        last_request.path.should == '/my_cool_index/post/_mapping'
      end

      it_should_behave_like 'put mapping'
    end # context 'with specified index'
  end # describe '::sync_mapping'

  describe '::find' do

    shared_examples_for 'single document lookup' do
      context 'when document is found' do
        before do
          stub_elasticsearch_get(
            index, 'post', '1',
          )
        end

        it 'should return post instance' do
          post.should be_a(Post)
        end

        it 'should request specified fields if specified' do
          scope.fields('name', 'author.name').find(1)
          last_request.path.should == "/#{index}/post/1?fields=name%2Cauthor.name"
        end

        it 'should return an array if id is passed in single-element array' do
          posts = scope.find([1])
          posts.should be_a(Array)
          posts.first.id.should == '1'
        end
      end

      context 'when document is not found' do
        before do
          stub_elasticsearch_get(index, 'post', '1', nil)
        end

        it 'should return nil' do
          scope.find(1).should be_nil
        end
      end
    end # shared_examples_for 'single document'

    shared_examples_for 'multi document single index lookup' do

      before do
        stub_elasticsearch_mget(index, 'post', '1', '2')
        posts
      end

      context 'with no options' do
        let(:posts) { scope.find('1', '2') }

        it 'should send request to index multiget endpoint' do
          last_request.path.should == "/#{index}/post/_mget"
        end

        it 'should ask for IDs' do
          last_request_body.should == {
            'docs' => [{ '_id' => '1'}, { '_id' => '2' }]
          }
        end

        it 'should return documents' do
          posts.map { |post| post.id }.should == %w(1 2)
        end
      end # context 'with no options'

      context 'with fields option provided' do
        let(:posts) { scope.fields('title').find('1', '2') }

        it 'should send fields with each id' do
          last_request_body.should == {
            'docs' => [
              { '_id' => '1', 'fields' => %w(title) },
              { '_id' => '2', 'fields' => %w(title) }
            ]
          }
        end
      end

      context 'with multi-element array passed' do
        let(:posts) { scope.find(%w(1 2)) }

        it 'should request listed elements' do
          last_request_body.should == {
            'docs' => [
              { '_id' => '1' },
              { '_id' => '2' }
            ]
          }
        end
      end
    end # shared_examples_for 'multi document single index lookup'

    context 'with default index' do
      let(:scope) { Post }
      let(:post) { Post.find(1) }
      let(:index) { 'default' }

      it_should_behave_like 'single document lookup'
      it_should_behave_like 'multi document single index lookup'

      describe 'multi-index multi-get' do
        before do
          stub_elasticsearch_mget(
            nil,
            nil,
            ['1', 'default'], ['2', 'my_index'], ['3', 'my_index']
          )
          posts
        end

        describe 'with no options' do
          let(:posts) { Post.find('default' => '1', 'my_index' => %w(2 3)) }

          it 'should send request to base path' do
            last_request.path.should == '/_mget'
          end

          it 'should request ids with type and index' do
            last_request_body.should == {
              'docs' => [{
                '_id' => '1',
                '_type' => 'post',
                '_index' => 'default'
              }, {
                '_id' => '2',
                '_type' => 'post',
                '_index' => 'my_index'
              }, {
                '_id' => '3',
                '_type' => 'post',
                '_index' => 'my_index'
              }]
            }
          end

          it 'should return docs with IDs' do
            posts.map(&:id).should == %w(1 2 3)
          end

          it 'should set proper indices' do
            posts.map { |post| post.index.name }.should ==
              %w(default my_index my_index)
          end
        end # context 'with no options' 

        context 'with fields specified' do
          let(:posts) { Post.fields('title').find('default' => '1', 'my_index' => %w(2 3)) }

          it 'should inject fields into each identifier' do
            last_request_body.should == {
              'docs' => [{
                '_id' => '1',
                '_type' => 'post',
                '_index' => 'default',
                'fields' => %w(title)
              }, {
                '_id' => '2',
                '_type' => 'post',
                '_index' => 'my_index',
                'fields' => %w(title)
              }, {
                '_id' => '3',
                '_type' => 'post',
                '_index' => 'my_index',
                'fields' => %w(title)
              }]
            }
          end
        end
      end # describe 'multi-index multi-get'

      context 'when documents are missing' do
        let(:posts) { Post.find('1', '2') }

        before do
          stub_elasticsearch_mget('default', 'post', '1' => {}, '2' => nil)
        end

        it 'should only return docs that exist' do
          posts.map(&:id).should == ['1']
        end
      end
    end # context 'with default index'

    context 'with specified index' do
      let(:scope) { Post.in_index('my_index') }
      let(:post) { Post.in_index('my_index').find(1) }
      let(:index) { 'my_index' }

      it_should_behave_like 'single document lookup'
      it_should_behave_like 'multi document single index lookup'
    end # context 'with specified index'
  end # describe '::find'

  describe '::new_from_elasticsearch_hit' do
    context 'with full _source' do
      let :post do
        Post.new.tap do |post|
          post.elasticsearch_hit = {
            '_id' => '1',
            '_index' => 'my_index',
            '_source' => {
              'title' => 'Testy time',
              'tags' => %w(search lucene),
              'author' => { 'name' => 'Mat Brown' },
              'comments' => [
                { 'body' => 'first comment' },
                { 'body' => 'lol' }
              ],
              'created_at' => '2011-09-12T13:27:16.345Z',
              'published_at' => 1315848697123
            }
          }
        end
      end

      it 'should populate id' do
        post.id.should == '1'
      end

      it 'should populate index' do
        post.index.name.should == 'my_index'
      end

      it 'should mark document perisistent' do
        post.should be_persisted
      end

      it 'should populate scalar in document' do
        post.title.should == 'Testy time'
      end

      it 'should populate time from formatted string' do
        post.created_at.should == Time.gm(2011, 9, 12, 13, 27, BigDecimal.new("16.345"))
      end

      it 'should populate time from millis since epoch' do
        post.published_at.should == Time.gm(2011, 9, 12, 17, 31, BigDecimal.new("37.123"))
      end

      it 'should populate array in document' do
        post.tags.should == %w(search lucene)
      end

      it 'should populate embedded field' do
        post.author.name.should == 'Mat Brown'
      end

      it 'should populate array of embedded objects' do
        post.comments.map { |comment| comment.body }.should ==
          ['first comment', 'lol']
      end
    end # context 'with full _source'

    context 'with specified fields' do
      let(:post) do
        Post.new.tap do |post|
          post.elasticsearch_hit = {
            '_id' => '1',
            '_index' => 'my_index',
            '_type' => 'post',
            'fields' => {
              'title' => 'Get efficient',
              '_source.comments_count' => 2,
              '_source.author' => {
                'id' => '1',
                'name' => 'Pontificator',
                'email' => 'pontificator@blogosphere.biz'
              },
              '_source.comments' => [{
                'body' => '#1 fun'
              }, {
                'body' => 'good fortune'
              }]
            }
          }
        end
      end

      it 'should populate scalar from stored field' do
        post.title.should == 'Get efficient'
      end

      it 'should populate scalar from _source' do
        post.comments_count.should == 2
      end

      it 'should populate single-valued embedded object' do
        post.author.name.should == 'Pontificator'
      end

      it 'should populate multi-valued embedded objects' do
        post.comments.map { |comment| comment.body }.should == [
          '#1 fun',
          'good fortune'
        ]
      end
    end

    describe 'with missing values for requested fields' do
      let(:post) do
        Post.new.tap do |post|
          post.elasticsearch_hit = {
            '_id' => '1',
            '_index' => 'my_index',
            'fields' => {
              'title' => nil,
              'author.name' => nil,
              '_source.comments' => nil
            }
          }
        end
      end

      it 'should set scalar from stored field to nil' do
        post.title.should be_nil
      end

      it 'should set embedded field to nil' do
        post.author.should be_nil
      end

      it 'should set object field from source ot nil' do
        post.comments.should be_nil
      end
    end
  end
end
