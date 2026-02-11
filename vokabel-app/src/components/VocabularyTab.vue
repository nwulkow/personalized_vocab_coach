<template>
  <div class="vocabulary-tab">
    <div v-if="!testStarted" class="setup-panel">
      <h2>Start Vocabulary Test</h2>
      
      <div class="form-group">
        <label>Start Language (shown to you):</label>
        <div class="language-selector">
          <img :src="`/${startLanguage}.png`" :alt="startLanguage" class="flag-icon" />
          <select v-model="startLanguage" class="language-select">
            <option value="german">German</option>
            <option value="english">English</option>
            <option value="spanish">Spanish</option>
            <option value="french">French</option>
          </select>
        </div>
      </div>

      <div class="form-group">
        <label>Target Language (you translate to):</label>
        <div class="language-selector">
          <img :src="`/${targetLanguage}.png`" :alt="targetLanguage" class="flag-icon" />
          <select v-model="targetLanguage" class="language-select">
            <option value="german">German</option>
            <option value="english">English</option>
            <option value="spanish">Spanish</option>
            <option value="french">French</option>
          </select>
        </div>
      </div>

      <div class="form-group">
        <label>Number of words (leave empty for all):</label>
        <input type="number" v-model.number="noWords" class="text-input" placeholder="Leave empty for all words" min="1" />
      </div>

      <div class="form-group">
        <label>Hide used word for N words:</label>
        <input type="number" v-model.number="hideUsedWordForNWords" class="text-input" min="0" />
      </div>

      <div class="form-group">
        <label>Probability for sentence creation (0-1):</label>
        <input type="number" v-model.number="probabilityForSentenceCreation" class="text-input" min="0" max="1" step="0.1" />
      </div>

      <div class="form-group">
        <label>Max words in created sentence:</label>
        <input type="number" v-model.number="maxNumWordsInCreatedSentence" class="text-input" min="1" />
      </div>

      <div class="form-group">
        <label>Language level for created sentence:</label>
        <select v-model="languageLevelForCreatedSentence" class="language-select">
          <option value="A1">A1</option>
          <option value="A2">A2</option>
          <option value="B1">B1</option>
          <option value="B2">B2</option>
          <option value="C1">C1</option>
          <option value="C2">C2</option>
        </select>
      </div>

      <div class="form-group">
        <label>Word filtering description (optional):</label>
        <input type="text" v-model="descriptionForWordFiltering" class="text-input" placeholder="e.g., 'Verbs only', 'Nouns only'" />
      </div>

      <div class="form-group">
        <label>
          <input type="checkbox" v-model="useVoice" />
          Enable voice synthesis
        </label>
      </div>

      <div class="form-group">
        <label>
          <input type="checkbox" v-model="hideCorrectlyTranslatedWords" />
          Hide correctly translated words
        </label>
      </div>

      <div class="form-group">
        <label>
          <input type="checkbox" v-model="beStringent" />
          Be stringent with answers
        </label>
      </div>

      <button @click="startTest" class="action-button primary" :disabled="startLanguage === targetLanguage">
        Start Test
      </button>
      
      <p v-if="startLanguage === targetLanguage" class="error-message">
        Please select different languages for start and target.
      </p>
    </div>

    <div v-else class="test-panel">
      <div class="test-header">
        <h2>{{ startLanguage.charAt(0).toUpperCase() + startLanguage.slice(1) }} → {{ targetLanguage.charAt(0).toUpperCase() + targetLanguage.slice(1) }}</h2>
        <button @click="endTest" class="action-button secondary">End Test</button>
      </div>

      <div v-if="loading" class="loading">
        <p>Loading next word...</p>
      </div>

      <div v-else-if="currentWord" class="word-card">
        <div class="word-display">
          <label>{{ startLanguage.charAt(0).toUpperCase() + startLanguage.slice(1) }}:</label>
          <h3>{{ currentWord.word_language_1 }}</h3>
        </div>

        <div v-if="!answerSubmitted" class="answer-section">
          <label>Your {{ targetLanguage.charAt(0).toUpperCase() + targetLanguage.slice(1) }} translation:</label>
          <input 
            v-model="userAnswer" 
            @keyup.enter="checkAnswer"
            class="answer-input"
            placeholder="Type your translation..."
            autofocus
          />
          <button @click="checkAnswer" class="action-button primary" :disabled="!userAnswer.trim()">
            Check Answer
          </button>
        </div>

        <div v-else class="result-section">
          <div v-if="checkingAnswer" class="checking-message">
            <span>🔍 Checking translation...</span>
          </div>
          <div v-else class="result-message" :class="{ correct: isCorrect, incorrect: !isCorrect }">
            <span v-if="isCorrect">✓ Correct!</span>
            <span v-else>✗ Incorrect</span>
          </div>
          <div class="correct-answer">
            <strong>Correct answer:</strong> {{ currentWord.word_language_2 }}
          </div>
          <button @click="nextWord" class="action-button primary">
            Next Word →
          </button>
        </div>

        <div class="stats">
          <span class="stat">Correct: {{ stats.correct }}</span>
          <span class="stat">Incorrect: {{ stats.incorrect }}</span>
          <span class="stat">Total: {{ stats.total }}</span>
        </div>
      </div>

      <div v-else class="no-words">
        <p>No words available for this language pair.</p>
        <button @click="endTest" class="action-button secondary">Back to Setup</button>
      </div>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue'
import axios from 'axios'

export default {
  name: 'VocabularyTab',
  setup() {
    const testStarted = ref(false)
    const startLanguage = ref('german')
    const targetLanguage = ref('english')
    const useVoice = ref(false)
    const loading = ref(false)
    
    // Test options from run_word_test.py
    const noWords = ref(null)
    const hideUsedWordForNWords = ref(4)
    const probabilityForSentenceCreation = ref(0.6)
    const maxNumWordsInCreatedSentence = ref(10)
    const languageLevelForCreatedSentence = ref('C1')
    const descriptionForWordFiltering = ref('')
    const hideCorrectlyTranslatedWords = ref(false)
    const beStringent = ref(false)
    
    const currentWord = ref(null)
    const userAnswer = ref('')
    const answerSubmitted = ref(false)
    const isCorrect = ref(false)
    const checkingAnswer = ref(false)
    
    const stats = ref({
      correct: 0,
      incorrect: 0,
      total: 0
    })

    const wordsList = ref([])

    const loadWordList = async () => {
      try {
        // Load the word list from CSV
        const response = await axios.get(`/api/word_list`, {
          params: {
            language_1: startLanguage.value,
            language_2: targetLanguage.value
          }
        })
        return response.data.words
      } catch (error) {
        console.error('Error loading word list:', error)
        return []
      }
    }

    const startTest = async () => {
      loading.value = true
      testStarted.value = true
      
      // Load word list
      let words = await loadWordList()
      
      // Apply filtering if description is provided
      if (descriptionForWordFiltering.value && descriptionForWordFiltering.value.trim() !== '') {
        try {
          const filterResponse = await axios.post('/api/filter_words', null, {
            params: {
              language: startLanguage.value,
              description: descriptionForWordFiltering.value
            }
          })
          
          if (filterResponse.data.filtered_words && filterResponse.data.filtered_words.length > 0) {
            words = filterResponse.data.filtered_words
            console.log(`Filtered to ${words.length} words matching: "${descriptionForWordFiltering.value}"`)
          } else {
            console.log('No words matched the filter, using full word list')
          }
        } catch (error) {
          console.error('Error filtering words:', error)
          // Continue with unfiltered list
        }
      }
      
      if (words && words.length > 0) {
        wordsList.value = words
      }
      
      await nextWord()
    }

    const nextWord = async () => {
      loading.value = true
      userAnswer.value = ''
      answerSubmitted.value = false
      isCorrect.value = false

      try {
        // Capitalize language names to match CSV column names
        const lang1Key = startLanguage.value.charAt(0).toUpperCase() + startLanguage.value.slice(1)
        const lang2Key = targetLanguage.value.charAt(0).toUpperCase() + targetLanguage.value.slice(1)
        
        const response = await axios.post('/api/create_word', {
          words_language_1: wordsList.value.map(w => w[lang1Key]),
          words_language_2: wordsList.value.map(w => w[lang2Key]),
          language_1: startLanguage.value,
          language_2: targetLanguage.value,
          probability_for_sentence_creation: probabilityForSentenceCreation.value,
          max_num_words_in_created_sentence: maxNumWordsInCreatedSentence.value,
          language_level_for_created_sentence: languageLevelForCreatedSentence.value
        })
        
        currentWord.value = response.data.word
        
        if (useVoice.value && currentWord.value.word_language_1) {
          // Optionally play voice
          // This would need additional API support
        }
      } catch (error) {
        console.error('Error getting word:', error)
        alert('Error loading word. Make sure the API server is running and word lists exist.')
      } finally {
        loading.value = false
      }
    }

    const checkAnswer = async () => {
      if (!userAnswer.value.trim()) return

      answerSubmitted.value = true
      checkingAnswer.value = true
      stats.value.total++

      try {
        const response = await axios.post('/api/check_translation', null, {
          params: {
            user_translation: userAnswer.value,
            correct_translation: currentWord.value.word_language_2,
            be_stringent: beStringent.value
          }
        })
        
        isCorrect.value = response.data.is_correct
        
        if (isCorrect.value) {
          stats.value.correct++
        } else {
          stats.value.incorrect++
        }
      } catch (error) {
        console.error('Error checking answer:', error)
        // Fallback to simple string comparison
        isCorrect.value = userAnswer.value.trim().toLowerCase() === currentWord.value.word_language_2.trim().toLowerCase()
        
        if (isCorrect.value) {
          stats.value.correct++
        } else {
          stats.value.incorrect++
        }
      } finally {
        checkingAnswer.value = false
      }
    }

    const endTest = () => {
      testStarted.value = false
      currentWord.value = null
      userAnswer.value = ''
      answerSubmitted.value = false
      stats.value = {
        correct: 0,
        incorrect: 0,
        total: 0
      }
    }

    return {
      testStarted,
      startLanguage,
      targetLanguage,
      useVoice,
      noWords,
      hideUsedWordForNWords,
      probabilityForSentenceCreation,
      maxNumWordsInCreatedSentence,
      languageLevelForCreatedSentence,
      descriptionForWordFiltering,
      hideCorrectlyTranslatedWords,
      beStringent,
      loading,
      currentWord,
      userAnswer,
      answerSubmitted,
      isCorrect,
      checkingAnswer,
      stats,
      startTest,
      nextWord,
      checkAnswer,
      endTest
    }
  }
}
</script>

<style scoped>
.vocabulary-tab {
  max-width: 800px;
  margin: 0 auto;
}

.setup-panel,
.test-panel {
  background: white;
  border-radius: 12px;
  padding: 2rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.setup-panel h2,
.test-header h2 {
  margin-top: 0;
  margin-bottom: 1.5rem;
  color: #667eea;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  font-weight: 600;
  margin-bottom: 0.5rem;
  color: #333;
}

.form-group input[type="checkbox"] {
  margin-right: 0.5rem;
}

.language-selector {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.flag-icon {
  width: 32px;
  height: 24px;
  object-fit: cover;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.language-select {
  width: 100%;
  padding: 0.75rem;
  border: 2px solid #e0e0e0;
  border-radius: 6px;
  font-size: 1rem;
  background-color: white;
  cursor: pointer;
  transition: border-color 0.3s ease;
}

.language-select:focus {
  outline: none;
  border-color: #667eea;
}

.text-input {
  width: 100%;
  padding: 0.75rem;
  border: 2px solid #e0e0e0;
  border-radius: 6px;
  font-size: 1rem;
  transition: border-color 0.3s ease;
}

.text-input:focus {
  outline: none;
  border-color: #667eea;
}

.action-button {
  padding: 1rem 2rem;
  font-size: 1.1rem;
  font-weight: 600;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s ease;
  width: 100%;
  margin-top: 1rem;
}

.action-button.primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  box-shadow: 0 4px 6px rgba(102, 126, 234, 0.3);
}

.action-button.primary:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 12px rgba(102, 126, 234, 0.4);
}

.action-button.primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-button.secondary {
  background: #6c757d;
  color: white;
}

.action-button.secondary:hover {
  background: #5a6268;
}

.error-message {
  color: #dc3545;
  margin-top: 1rem;
  font-weight: 500;
}

.test-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.test-header .action-button {
  width: auto;
  margin-top: 0;
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
}

.loading {
  text-align: center;
  padding: 3rem;
  color: #667eea;
  font-size: 1.2rem;
}

.word-card {
  margin-top: 2rem;
}

.word-display {
  text-align: center;
  margin-bottom: 2rem;
  padding: 2rem;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
  border-radius: 8px;
}

.word-display label {
  font-size: 0.9rem;
  color: #667eea;
  font-weight: 600;
  text-transform: uppercase;
}

.word-display h3 {
  margin: 0.5rem 0 0;
  font-size: 2rem;
  color: #333;
}

.answer-section {
  margin-bottom: 2rem;
}

.answer-section label {
  display: block;
  font-weight: 600;
  margin-bottom: 0.5rem;
  color: #333;
}

.answer-input {
  width: 100%;
  padding: 1rem;
  border: 2px solid #e0e0e0;
  border-radius: 6px;
  font-size: 1.2rem;
  margin-bottom: 1rem;
  transition: border-color 0.3s ease;
}

.answer-input:focus {
  outline: none;
  border-color: #667eea;
}

.result-section {
  text-align: center;
}

.checking-message {
  font-size: 1.5rem;
  font-weight: 700;
  padding: 1rem;
  border-radius: 8px;
  margin-bottom: 1rem;
  background-color: #fff3cd;
  color: #856404;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

.result-message {
  font-size: 1.5rem;
  font-weight: 700;
  padding: 1rem;
  border-radius: 8px;
  margin-bottom: 1rem;
}

.result-message.correct {
  background-color: #d4edda;
  color: #155724;
}

.result-message.incorrect {
  background-color: #f8d7da;
  color: #721c24;
}

.correct-answer {
  font-size: 1.1rem;
  margin-bottom: 1.5rem;
  padding: 1rem;
  background-color: #f8f9fa;
  border-radius: 6px;
}

.stats {
  display: flex;
  justify-content: space-around;
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 2px solid #e0e0e0;
}

.stat {
  font-size: 1.1rem;
  font-weight: 600;
  color: #667eea;
}

.no-words {
  text-align: center;
  padding: 3rem;
}

.no-words p {
  font-size: 1.2rem;
  color: #6c757d;
  margin-bottom: 1.5rem;
}
</style>
