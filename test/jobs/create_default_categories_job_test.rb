require "test_helper"
require "minitest/mock"

class CreateDefaultCategoriesJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one) # Assuming you have fixtures for users
    # Clear any existing categories/sentences for the user to ensure clean test state
    @user.categories.destroy_all
    @user.sentences.destroy_all

    # Ensure languages exist, or create them if necessary for tests
    Language.find_or_create_by!(code: "en", name: "English")
    Language.find_or_create_by!(code: "de", name: "German")
    Language.find_or_create_by!(code: "fr", name: "French") # For testing a case where a CSV might be missing
  end

  test "perform successful run creates categories and sentences" do
    Language.stub :pluck, %w[en de] do
      # Mock CSV.foreach for categories.csv
      mock_category_data = [
        { "name" => "Greetings", "icon_name" => "hand.wave" },
        { "name" => "Farewells", "icon_name" => "door.left.hand.open" }
      ]
      CSV.stub :foreach, ->(path, headers:, &block) {
        if path.to_s.end_with?("categories.csv")
          mock_category_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
        elsif path.to_s.end_with?("sentences_en.csv")
          mock_sentences_en_data = [
            { "category" => "Greetings", "content" => "Hello" },
            { "category" => "Greetings", "content" => "Hi there" },
            { "category" => "Farewells", "content" => "Goodbye" }
          ]
          mock_sentences_en_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
        elsif path.to_s.end_with?("sentences_de.csv")
          mock_sentences_de_data = [
            { "category" => "Greetings", "content" => "Hallo" },
            { "category" => "Farewells", "content" => "Auf Wiedersehen" }
          ]
          mock_sentences_de_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
        end
      } do
        CreateDefaultCategoriesJob.perform_now(@user)
      end
    end

    @user.reload
    assert_equal 2, @user.categories.count, "Should create 2 categories"
    assert_equal ["Farewells", "Greetings"], @user.categories.order(:name).pluck(:name)
    assert_equal 5, @user.sentences.count, "Should create 5 sentences in total"

    greeting_category = @user.categories.find_by(name: "Greetings")
    assert greeting_category
    assert_equal 2, greeting_category.sentences.where(language: Language.find_by(code: "en")).count
    assert_equal 1, greeting_category.sentences.where(language: Language.find_by(code: "de")).count
    assert_equal "Hello", greeting_category.sentences.find_by(language: Language.find_by(code: "en"), content: "Hello").content
  end

  test "perform with category save failure logs error and handles gracefully" do
    Language.stub :pluck, %w[en] do
      mock_category_data = [ { "name" => "Failing Category", "icon_name" => "problem" } ]
      CSV.stub :foreach, ->(path, headers:, &block) {
        # Only mock category CSV, sentence CSV won't be reached if category fails
        if path.to_s.end_with?("categories.csv")
          mock_category_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
        end
      } do
        # Mock Category.save to fail for the specific category
        # This is a bit tricky as the Category is found or initialized within the job.
        # We can stub `find_or_initialize_by` to return a mock that fails on save.
        
        mock_category = Category.new(user: @user, name: "Failing Category")
        mock_category.errors.add(:base, "Simulated save error")
        
        # Stub find_or_initialize_by to return our mock that will fail
        # And then ensure save returns false
        Category.any_instance.stub :save, false do 
          # Log expectation
          Rails.logger.expects(:error).with(regexp_matches(/Error saving category Failing Category/))
          
          CreateDefaultCategoriesJob.perform_now(@user)
        end
      end
    end
    @user.reload
    assert_equal 0, @user.categories.count, "Should not create the failing category"
    assert_equal 0, @user.sentences.count, "Should not create any sentences if category creation fails"
  end

  test "perform with missing sentence CSV file logs warning and processes other languages" do
    # Ensure 'fr' language exists for this test, but its CSV will be "missing"
    Language.find_or_create_by!(code: "fr", name: "French")
    
    Language.stub :pluck, %w[en fr de] do # 'fr' is the one we'll make "missing"
      mock_category_data = [ { "name" => "General", "icon_name" => "info" } ]
      mock_sentences_en_data = [ { "category" => "General", "content" => "English sentence" } ]
      mock_sentences_de_data = [ { "category" => "General", "content" => "German sentence" } ]

      # Simulate File.exist? returning false for the French CSV
      File.stub :exist?, ->(path) {
        return false if path.to_s.end_with?("sentences_fr.csv")
        true # Assume other files exist
      } do
        CSV.stub :foreach, ->(path, headers:, &block) {
          if path.to_s.end_with?("categories.csv")
            mock_category_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
          elsif path.to_s.end_with?("sentences_en.csv")
            mock_sentences_en_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
          elsif path.to_s.end_with?("sentences_de.csv")
            mock_sentences_de_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
          elsif path.to_s.end_with?("sentences_fr.csv")
            # This block should not be reached due to File.exist? stub
            raise "French CSV should not have been processed"
          end
        } do
          Rails.logger.expects(:warn).with(regexp_matches(/CSV file not found for language 'fr'/))
          CreateDefaultCategoriesJob.perform_now(@user)
        end
      end
    end

    @user.reload
    assert_equal 1, @user.categories.count, "Should create 1 category"
    assert_equal "General", @user.categories.first.name
    assert_equal 2, @user.sentences.count, "Should create sentences for EN and DE, but not FR"
    assert_equal 1, @user.sentences.where(language: Language.find_by(code: "en")).count
    assert_equal 1, @user.sentences.where(language: Language.find_by(code: "de")).count
    assert_equal 0, @user.sentences.where(language: Language.find_by(code: "fr")).count
  end

  test "perform when no languages are found in database" do
    Language.stub :pluck, [] do # No languages
      Rails.logger.expects(:error).with("No languages found in the database. Cannot create default sentences.")
      CreateDefaultCategoriesJob.perform_now(@user)
    end
    @user.reload
    assert_equal 0, @user.categories.count # Categories might still be created if CSV is processed before language check
                                           # The current job structure processes categories first.
                                           # If categories should NOT be created if no languages, job logic needs change.
                                           # Based on current job: categories CSV is processed, then languages.
                                           # Let's refine this test based on actual job logic: Categories will be created.
    
    # Re-running with refined expectation for category creation
    mock_category_data = [ { "name" => "Greetings", "icon_name" => "hand.wave" } ]
    CSV.stub :foreach, ->(path, headers:, &block) {
      if path.to_s.end_with?("categories.csv")
        mock_category_data.each { |row| block.call(CSV::Row.new(row.keys, row.values)) }
      end
    } do
      Language.stub :pluck, [] do # No languages
        Rails.logger.expects(:error).with("No languages found in the database. Cannot create default sentences.")
        CreateDefaultCategoriesJob.perform_now(@user)
      end
    end
    @user.reload
    assert_equal 1, @user.categories.count, "Categories should be created even if no languages found"
    assert_equal 0, @user.sentences.count, "No sentences should be created if no languages found"

  end
end
