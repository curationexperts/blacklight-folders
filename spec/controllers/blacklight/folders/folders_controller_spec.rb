require 'rails_helper'

describe Blacklight::Folders::FoldersController do
  routes { Blacklight::Folders::Engine.routes }

  let(:user) { FactoryGirl.create(:user) }
  let(:my_private_folder) { FactoryGirl.create(:private_folder, user: user) }
  let(:my_public_folder)  { FactoryGirl.create(:public_folder, user: user) }


  describe 'not logged in' do
    describe '#new' do
      it 'denies access' do
        get :new
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#show' do
      it 'displays public folders' do
        get :show, id: my_public_folder.id
        expect(response).to be_successful
        expect(response).to render_template(:show)
        expect(assigns(:folder)).to eq my_public_folder
      end

      it 'denies access to private folders' do
        get :show, id: my_private_folder.id
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#edit' do
      it 'denies access' do
        get :edit, id: my_public_folder.id
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#destroy' do
      it 'denies access' do
        delete :destroy, id: my_public_folder.id
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#create' do
      it 'denies access' do
        post :create, folder: { name: 'My Folder' }
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#update' do
      it 'denies access' do
        patch :update, id: my_public_folder.id, folder: { name: 'hello' }
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#index' do
      it 'denies access' do
        get :index
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#add_bookmarks' do
      it 'denies access' do
        patch :add_bookmarks, folder: { id: my_public_folder.id }, document_ids: '123'
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end

    describe '#remove_bookmarks' do
      it 'denies access' do
        patch :remove_bookmarks, folder: { id: my_public_folder.id }, item_ids: '123'
        expect(response).to redirect_to(main_app.user_session_path)
      end
    end
  end  # not logged in


  describe 'user is logged in' do
    before { sign_in user }

    describe '#new' do
      it 'displays the form' do
        get :new
        expect(response).to be_successful
        expect(response).to render_template(:new)
        expect(assigns(:folder)).to be_a_new(Blacklight::Folders::Folder)
      end
    end

    describe '#show' do
      it 'displays the folder' do
        get :show, id: my_private_folder.id
        expect(response).to be_successful
        expect(response).to render_template(:show)
        expect(assigns(:folder)).to eq my_private_folder
      end
    end

    describe '#edit' do
      it 'displays the form' do
        get :edit, id: my_private_folder.id
        expect(response).to be_successful
        expect(response).to render_template(:edit)
        expect(assigns(:folder)).to eq my_private_folder
      end
    end

    describe '#destroy' do
      it 'destroys the folder' do
        my_private_folder
        expect {
          delete :destroy, id: my_private_folder.id
        }.to change{ Blacklight::Folders::Folder.count }.by(-1)
        expect(response).to redirect_to main_app.root_path
      end
    end

    describe '#create' do
      it 'creates a folder with current user as owner' do
        expect {
          post :create, folder: { name: 'My Folder' }
        }.to change{ Blacklight::Folders::Folder.count }.by(1)
        expect(assigns(:folder)).to_not be_nil
        expect(assigns(:folder).user).to eq user
        expect(response).to redirect_to folder_path(assigns(:folder))
      end
    end

    describe '#create with bad inputs' do
      it 'renders the form' do
        invalid_name = nil
        expect {
          post :create, folder: { name: invalid_name }
        }.to change{ Blacklight::Folders::Folder.count }.by(0)
        expect(assigns(:folder)).to_not be_nil
        expect(response).to render_template(:new)
      end
    end

    describe '#update' do
      it 'updates the folder' do
        my_private_folder
        new_name = 'New Name'
        patch :update, id: my_private_folder.id, folder: { name: new_name }
        expect(assigns(:folder)).to eq my_private_folder
        expect(response).to redirect_to folder_path(my_private_folder)
        expect(my_private_folder.reload.name).to eq new_name
      end
    end

    describe '#update with bad inputs' do
      it 'renders the form' do
        my_private_folder
        invalid_name = nil
        patch :update, id: my_private_folder.id, folder: { name: invalid_name }
        expect(assigns(:folder)).to eq my_private_folder
        expect(response).to render_template(:edit)
      end
    end

    describe '#index' do
      before do
        my_private_folder
        my_public_folder
      end

      it 'displays the folders' do
        get :index

        expect(assigns(:folders)).to match_array [my_private_folder, my_public_folder]
        expect(response).to render_template(:index)
        expect(response).to be_successful
      end

      context "with sorting" do
        let!(:aaa_folder)  { FactoryGirl.create(:public_folder, user: user, name: 'AAA') }

        it 'displays the folders in order' do
          get :index, order_by: 'name'

          expect(assigns(:folders)).to eq [aaa_folder, my_private_folder, my_public_folder]
          expect(response).to render_template(:index)
          expect(response).to be_successful
        end
      end
    end

    describe '#add_bookmarks' do
      it 'adds bookmarks to the folder' do
        @request.env['HTTP_REFERER'] = 'http://test.com'
        patch :add_bookmarks, folder: { id: my_public_folder.id }, document_ids: '123, 456'

        expect(response).to redirect_to :back
        expect(assigns(:folder)).to eq my_public_folder
        expect(my_public_folder.bookmarks.count).to eq 2
        expect(my_public_folder.bookmarks.map(&:document_id).sort).to eq ['123', '456'].sort
      end
    end

    describe '#add_bookmarks failure path' do
      before do
        allow_any_instance_of(Blacklight::Folders::Folder).to receive(:save) { false }
        @request.env['HTTP_REFERER'] = 'http://test.com'
      end

      it 'prints an error' do
        patch :add_bookmarks, folder: { id: my_public_folder.id }, document_ids: '123, 456'
        expect(response).to redirect_to :back
        expect(flash[:alert]).to eq 'Unable to save bookmarks.'
      end
    end

    describe '#remove_bookmarks' do
      before do
        my_public_folder.bookmarks.build({document_id: '123', document_type: 'SolrDocument', user_id: my_public_folder.user_id })
        my_public_folder.save!
        @item = my_public_folder.items.first
        @request.env['HTTP_REFERER'] = 'http://test.com'
      end

      it 'removes the bookmarks' do
        expect(my_public_folder.bookmarks.count).to eq 1
        patch :remove_bookmarks, folder: { id: my_public_folder.id }, item_ids: @item.id
        my_public_folder.reload
        expect(response).to redirect_to :back
        expect(assigns(:folder)).to eq my_public_folder
        expect(my_public_folder.bookmarks.count).to eq 0
      end

      it "doesn't let you delete someone else's bookmark" do
        not_my_item = FactoryGirl.create(:bookmarks_folder)
        count = Blacklight::Folders::BookmarksFolder.count
        patch :remove_bookmarks, folder: { id: my_public_folder.id }, item_ids: not_my_item.id
        expect(Blacklight::Folders::BookmarksFolder.count).to eq count
      end
    end
  end  # user is logged in

end
