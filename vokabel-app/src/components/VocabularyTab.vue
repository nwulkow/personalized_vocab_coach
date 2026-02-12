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
        <div class="header-info">
          <span class="words-left">{{ wordsList.length }} {{ wordsList.length === 1 ? 'word' : 'words' }} left</span>
          <button @click="endTest" class="action-button secondary">End Test</button>
        </div>
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
            ref="answerInput"
            v-model="userAnswer" 
            @keyup.enter="checkAnswer"
            class="answer-input"
            placeholder="Type your translation..."
          />
          <button @click="checkAnswer" class="action-button primary" :disabled="!userAnswer.trim()">
            Check Answer
          </button>
        </div>

        <div v-else ref="resultSection" class="result-section" @keyup.enter="nextWord" tabindex="0">
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
        <p>No words left for this language pair!</p>
        <button @click="endTest" class="action-button secondary">Back to Setup</button>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, nextTick } from 'vue'
import axios from 'axios'

export default {
  name: 'VocabularyTab',
  setup() {
    const testStarted = ref(false)
    const startLanguage = ref('german')
    const targetLanguage = ref('english')
    const useVoice = ref(false)
    const loading = ref(false)
    const answerInput = ref(null)
    const resultSection = ref(null)
    
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
    const usedWordIndices = ref([])
    const correctlyAnsweredIndices = ref([])
    const availableWordsIndices = ref([]) // Maps filtered word indices to original wordsList indices

    // Shuffle two arrays in the same random order (Fisher-Yates)
    const shufflePairedArrays = (a, b) => {
      for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        ;[a[i], a[j]] = [a[j], a[i]]
        ;[b[i], b[j]] = [b[j], b[i]]
      }
    }

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
      
      // Reset tracking arrays
      usedWordIndices.value = []
      correctlyAnsweredIndices.value = []
      
      // Load word list
      let words = await loadWordList()
      
      // Add original indices to each word before any filtering
      words = words.map((word, index) => ({ ...word, _originalIndex: index }))
      
      // Apply filtering if description is provided
      if (descriptionForWordFiltering.value && descriptionForWordFiltering.value.trim() !== '') {
        try {
          const lang1Key = startLanguage.value.charAt(0).toUpperCase() + startLanguage.value.slice(1)
          const languagePair = `${startLanguage.value}_${targetLanguage.value}`
          
          const filterResponse = await axios.post('/api/filter_words', null, {
            params: {
              language: startLanguage.value,
              description: descriptionForWordFiltering.value,
              language_pair: languagePair
            }
          })
          
          if (filterResponse.data.filtered_words && filterResponse.data.filtered_words.length > 0) {
            const filteredWords = filterResponse.data.filtered_words
            // Match filtered words back to original list to preserve indices
            words = words.filter(w => 
              filteredWords.some(fw => fw[lang1Key] === w[lang1Key])
            )
            // Note: words still have _originalIndex property from when we loaded them
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

      // If there are no words left in the in-memory list, show the no-words UI
      if (!wordsList.value || wordsList.value.length === 0) {
        console.log('No words left in wordsList, showing no-words UI')
        loading.value = false
        currentWord.value = null
        return
      }

      try {
        // Capitalize language names to match CSV column names
        const lang1Key = startLanguage.value.charAt(0).toUpperCase() + startLanguage.value.slice(1)
        const lang2Key = targetLanguage.value.charAt(0).toUpperCase() + targetLanguage.value.slice(1)
        
        // Create a filtered list of words based on settings, tracking original indices
        const availableWords = []
        const indexMapping = [] // Maps availableWords index to wordsList index
        
        wordsList.value.forEach((word) => {
          const originalIndex = word._originalIndex // Use the stored original index
          
          // If hideCorrectlyTranslatedWords is enabled, exclude correctly answered words
          if (hideCorrectlyTranslatedWords.value && correctlyAnsweredIndices.value.includes(originalIndex)) {
            return
          }
          
          // Exclude recently used words based on hideUsedWordForNWords
          if (usedWordIndices.value.length > 0 && hideUsedWordForNWords.value > 0) {
            const recentlyUsed = usedWordIndices.value.slice(-hideUsedWordForNWords.value)
            if (recentlyUsed.includes(originalIndex)) {
              return
            }
          }
          
          availableWords.push(word)
          indexMapping.push(originalIndex)
        })
        
        // If no words are available, use the full list (prevents getting stuck)
        if (availableWords.length === 0) {
          wordsList.value.forEach((word) => {
            availableWords.push(word)
            indexMapping.push(word._originalIndex)
          })
        }
        
        // Shuffle available words to avoid repetitive ordering, then store the index mapping for later use
        shufflePairedArrays(availableWords, indexMapping)
        availableWordsIndices.value = indexMapping
        
        console.log('Total words in list:', wordsList.value.length)
        console.log('Available words after filtering:', availableWords.length)
        console.log('Recently used indices (last N):', usedWordIndices.value.slice(-hideUsedWordForNWords.value))
        console.log('Correctly answered indices:', correctlyAnsweredIndices.value)
        console.log('hideCorrectlyTranslatedWords setting:', hideCorrectlyTranslatedWords.value)
        console.log('Available word indices (first 5):', indexMapping.slice(0, 5))
        
        const response = await axios.post('/api/create_word', {
          words_language_1: availableWords.map(w => w[lang1Key]),
          words_language_2: availableWords.map(w => w[lang2Key]),
          language_1: startLanguage.value,
          language_2: targetLanguage.value,
          probability_for_sentence_creation: probabilityForSentenceCreation.value,
          max_num_words_in_created_sentence: maxNumWordsInCreatedSentence.value,
          language_level_for_created_sentence: languageLevelForCreatedSentence.value,
          original_indices: indexMapping
        })
        
        currentWord.value = response.data.word
        
        // Backend returns the original index when we provide `original_indices`.
        const backendIndex = response.data.word.word_index
        console.log('Backend returned word_index (original index):', backendIndex)
        if (backendIndex !== null && backendIndex !== undefined) {
          const originalWordIndex = backendIndex
          usedWordIndices.value.push(originalWordIndex)
          // Store the original index on the word for later use in checkAnswer
          currentWord.value.original_index = originalWordIndex
          console.log('Tracked used original index:', originalWordIndex)
        } else {
          console.warn('Backend returned invalid word_index:', backendIndex)
        }
        
        if (useVoice.value && currentWord.value.word_language_1) {
          // Optionally play voice
          // This would need additional API support
        }
      } catch (error) {
        console.error('Error getting word:', error)
        alert('Error loading word. Make sure the API server is running and word lists exist.')
      } finally {
        loading.value = false
        // Focus the input field after loading the word
        await nextTick()
        if (answerInput.value) {
          answerInput.value.focus()
        }
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
          
          // Track correctly answered word if hideCorrectlyTranslatedWords is enabled
          if (hideCorrectlyTranslatedWords.value && currentWord.value && currentWord.value.original_index !== undefined) {
            const wordIndex = currentWord.value.original_index
            console.log('🎯 Correct answer! Tracking word with original_index:', wordIndex)
            console.log('   hideCorrectlyTranslatedWords is:', hideCorrectlyTranslatedWords.value)
            console.log('   Word:', currentWord.value.word_language_1, '→', currentWord.value.word_language_2)
            if (!correctlyAnsweredIndices.value.includes(wordIndex)) {
              correctlyAnsweredIndices.value.push(wordIndex)
              console.log('   Added to correctlyAnsweredIndices. New list:', correctlyAnsweredIndices.value)
              // Also remove the word from wordsList to ensure it won't reappear
              wordsList.value = wordsList.value.filter(w => w._originalIndex !== wordIndex)
              console.log('   Removed word from wordsList. New length:', wordsList.value.length)
            } else {
              console.log('   Already in correctlyAnsweredIndices')
            }
          } else {
            console.log('❌ NOT tracking correct answer. hideCorrectlyTranslatedWords:', hideCorrectlyTranslatedWords.value, 'original_index:', currentWord.value?.original_index)
          }
        } else {
          stats.value.incorrect++
        }
      } catch (error) {
        console.error('Error checking answer:', error)
        // Fallback to simple string comparison
        isCorrect.value = userAnswer.value.trim().toLowerCase() === currentWord.value.word_language_2.trim().toLowerCase()
        
        if (isCorrect.value) {
          stats.value.correct++
          
          // Track correctly answered word if hideCorrectlyTranslatedWords is enabled
          if (hideCorrectlyTranslatedWords.value && currentWord.value && currentWord.value.original_index !== undefined) {
            const wordIndex = currentWord.value.original_index
            console.log('🎯 Correct answer (fallback)! Tracking word with original_index:', wordIndex)
            console.log('   Word:', currentWord.value.word_language_1, '→', currentWord.value.word_language_2)
            if (!correctlyAnsweredIndices.value.includes(wordIndex)) {
              correctlyAnsweredIndices.value.push(wordIndex)
              console.log('   Added to correctlyAnsweredIndices. New list:', correctlyAnsweredIndices.value)
              // Also remove the word from wordsList to ensure it won't reappear
              wordsList.value = wordsList.value.filter(w => w._originalIndex !== wordIndex)
              console.log('   Removed word from wordsList. New length:', wordsList.value.length)
            } else {
              console.log('   Already in correctlyAnsweredIndices')
            }
          } else {
            console.log('❌ NOT tracking correct answer (fallback). hideCorrectlyTranslatedWords:', hideCorrectlyTranslatedWords.value, 'original_index:', currentWord.value?.original_index)
          }
        } else {
          stats.value.incorrect++
        }
      } finally {
        checkingAnswer.value = false
        // Focus the result section after checking answer to enable Enter key for next word
        await nextTick()
        if (resultSection.value) {
          resultSection.value.focus()
        }
      }
    }

    const endTest = () => {
      testStarted.value = false
      currentWord.value = null
      userAnswer.value = ''
      answerSubmitted.value = false
      usedWordIndices.value = []
      correctlyAnsweredIndices.value = []
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
      answerInput,
      resultSection,
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
  padding-bottom: 1rem;
  border-bottom: 2px solid #e0e0e0;
}

.test-header h2 {
  margin: 0;
  color: #667eea;
}

.header-info {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.words-left {
  font-size: 1rem;
  font-weight: 600;
  color: #667eea;
  background-color: #f0f4ff;
  padding: 0.5rem 1rem;
  border-radius: 20px;
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
  outline: none;
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
