require_relative 'spec_helper'

RSpec.describe GeneralController, 'Handlingar frontpage overlay', type: :controller do
  before do
    allow(controller).to receive(:perform_search).
      and_return(double('search result', results: []))
  end

  it 'renders the frontpage template' do
    get :frontpage
    expect(response).to be_successful
    expect(response).to render_template('frontpage')
  end
end

RSpec.describe Users::SessionsController, 'Handlingar auth overlay', type: :controller do
  before do
    allow(controller).to receive(:country_from_ip).and_return('gb')
  end

  it 'renders the combined sign-in / create-account template' do
    get :new
    expect(response).to be_successful
    expect(response).to render_template('user/sign')
  end
end

RSpec.describe PublicBodyController, 'Handlingar authorities overlay', type: :controller do
  it 'renders the authority list template' do
    get :list
    expect(response).to be_successful
    expect(response).to render_template('public_body/list')
  end
end
