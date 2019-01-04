# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Signalwire::REST::Client do
  before :all do
    Signalwire::Sdk.configure do |config|
      config.hostname = ENV.fetch('SIGNALWIRE_SPACE', 'testing.signalwire.com')
    end
  end

  before :each do
    @client = Signalwire::REST::Client.new ENV.fetch('SIGNALWIRE_ACCOUNT', 'xyz123-xyz123-xyz123'),
    ENV.fetch('SIGNALWIRE_TOKEN', 'PTxyz123-xyz123-xyz123')
  end

  it "fetches accounts" do
    VCR.use_cassette("accounts") do
      accounts = @client.api.accounts.list
      expect(accounts.first.friendly_name).to eq 'LAML testing'
    end
  end

  it 'fetches applications' do
    VCR.use_cassette('applications') do
      applications = @client.applications.list
      expect(applications.first.sid).to eq '34f49a97-a863-4a11-8fef-bc399c6f0928'
    end
  end

  it 'fetches local numbers' do
    VCR.use_cassette('local_numbers') do
      numbers = @client.api.available_phone_numbers('US').local.list(in_region: 'WA')
      expect(numbers.first.phone_number).to eq '+12062011680'
    end
  end

  it 'fetches toll free numbers' do
    VCR.use_cassette('toll_free_numbers') do
      numbers = @client.api.available_phone_numbers('US').toll_free.list(area_code: '310')
      expect(numbers.first.phone_number).to eq '+13102174822'
    end
  end

  it 'fetches recordings' do
    VCR.use_cassette('recordings') do
      recordings = @client.recordings.list
      expect(recordings.first.call_sid).to eq 'd411976d-d319-4fbd-923c-57c62b6f677a'
    end
  end

  it 'fetches transcriptions' do
    VCR.use_cassette('transcriptions') do
      recordings = @client.transcriptions.list
      expect(recordings.first.recording_sid).to eq 'e4c78e17-c0e2-441d-b5dd-39a6dad496f8'
    end
  end

  context 'faxes' do
    it 'sends a fax' do
      VCR.use_cassette('send_fax') do
        fax = @client.fax.faxes
        .create(
          from: '+15556677888',
          to: '+15556677999',
          media_url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf'
        )
        expect(fax.sid).to eq '831455c6-574e-4d8b-b6ee-2418140bf4cd'
      end
    end

    it 'lists faxes' do
      VCR.use_cassette('list_faxes') do
        faxes = @client.fax.faxes.list
        expect(faxes.first.sid).to eq '831455c6-574e-4d8b-b6ee-2418140bf4cd'
      end
    end

    it 'gets a fax' do
      VCR.use_cassette('get_fax') do
        fax = @client.fax.faxes('831455c6-574e-4d8b-b6ee-2418140bf4cd').fetch
        expect(fax.to).to eq '+14043287360'
        expect(fax.media_url).to eq 'https://s3.us-east-2.amazonaws.com/signalwire-assets/faxes/20190104162834-831455c6-574e-4d8b-b6ee-2418140bf4cd.tiff'
      end
    end

    it 'gets a faxes media' do
      VCR.use_cassette('get_fax_media_list') do
        fax = @client.fax.faxes('831455c6-574e-4d8b-b6ee-2418140bf4cd').fetch
        expect(fax.media.list.first.sid).to eq 'aff0684c-3445-49bc-802b-3a0a488139f5'
      end
    end

    it 'gets a media instance' do
      VCR.use_cassette('get_fax_media_instance') do
        fax_media = @client.fax.faxes('831455c6-574e-4d8b-b6ee-2418140bf4cd').media('aff0684c-3445-49bc-802b-3a0a488139f5').fetch
        expect(fax_media.content_type).to eq 'image/tiff'
        expect(fax_media.url).to eq '/api/laml/2010-04-01/Accounts/xyz123-xyz123-xyz123/Faxes/831455c6-574e-4d8b-b6ee-2418140bf4cd/Media/aff0684c-3445-49bc-802b-3a0a488139f5.json'
      end
    end
  end
end
