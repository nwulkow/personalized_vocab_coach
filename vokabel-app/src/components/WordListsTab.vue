<template>
  <div class="word-lists-tab">
    <h2>Vocabulary Lists</h2>
    
    <div class="language-selector">
      <div class="form-group">
        <label>Select Word List:</label>
        <div class="list-selector-with-flags">
          <div class="flag-pair">
            <img :src="`/${selectedList.split('_')[0]}.png`" :alt="selectedList.split('_')[0]" class="flag-icon" />
            <img :src="`/${selectedList.split('_')[1]}.png`" :alt="selectedList.split('_')[1]" class="flag-icon" />
          </div>
          <select v-model="selectedList" @change="loadWordList" class="language-select">
            <option value="german_english">German ↔ English</option>
            <option value="german_spanish">German ↔ Spanish</option>
            <option value="german_french">German ↔ French</option>
          </select>
        </div>
      </div>
    </div>

    <div v-if="loading" class="loading">
      <p>Loading word list...</p>
    </div>

    <div v-else-if="words.length > 0" class="word-list-container">
      <div class="word-list-header">
        <div class="column-header">{{ language1 }}</div>
        <div class="column-header">{{ language2 }}</div>
        <div class="column-header actions-header">Actions</div>
      </div>

      <div class="word-list-rows">
        <div v-for="(word, index) in words" :key="index" class="word-row">
          <input 
            v-model="word.word1" 
            class="word-input"
            :placeholder="`${language1} word`"
          />
          <input 
            v-model="word.word2" 
            class="word-input"
            :placeholder="`${language2} word`"
          />
          <button @click="deleteWord(index)" class="delete-button" title="Delete word">
            🗑️
          </button>
        </div>
      </div>

      <div class="actions">
        <button @click="addNewWord" class="action-button secondary">
          ➕ Add New Word
        </button>
        <button @click="saveChanges" class="action-button primary" :disabled="saving">
          {{ saving ? 'Saving...' : '💾 Save Changes' }}
        </button>
      </div>

      <div v-if="message" :class="['message', messageType]">
        {{ message }}
      </div>
    </div>

    <div v-else class="no-words">
      <p>No words in this list yet.</p>
      <button @click="addNewWord" class="action-button primary">
        ➕ Add First Word
      </button>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue'
import axios from 'axios'

export default {
  name: 'WordListsTab',
  setup() {
    const selectedList = ref('german_english')
    const words = ref([])
    const loading = ref(false)
    const saving = ref(false)
    const message = ref('')
    const messageType = ref('success')
    const language1 = ref('German')
    const language2 = ref('English')

    const getLanguagesFromList = (listName) => {
      const parts = listName.split('_')
      return {
        lang1: parts[0].charAt(0).toUpperCase() + parts[0].slice(1),
        lang2: parts[1].charAt(0).toUpperCase() + parts[1].slice(1)
      }
    }

    const loadWordList = async () => {
      loading.value = true
      message.value = ''

      const langs = getLanguagesFromList(selectedList.value)
      language1.value = langs.lang1
      language2.value = langs.lang2

      try {
        const response = await axios.get('/api/word_list', {
          params: {
            language_1: selectedList.value.split('_')[0],
            language_2: selectedList.value.split('_')[1]
          }
        })

        // Transform the data to editable format
        words.value = response.data.words.map(word => ({
          word1: word[langs.lang1] || '',
          word2: word[langs.lang2] || ''
        }))
      } catch (error) {
        console.error('Error loading word list:', error)
        message.value = 'Error loading word list'
        messageType.value = 'error'
        words.value = []
      } finally {
        loading.value = false
      }
    }

    const addNewWord = () => {
      words.value.push({
        word1: '',
        word2: ''
      })
    }

    const deleteWord = (index) => {
      if (confirm('Are you sure you want to delete this word pair?')) {
        words.value.splice(index, 1)
      }
    }

    const saveChanges = async () => {
      saving.value = true
      message.value = ''

      try {
        const langs = selectedList.value.split('_')
        
        // Filter out empty rows
        const validWords = words.value.filter(word => 
          word.word1.trim() && word.word2.trim()
        )

        // Save the entire word list (replacing the old one)
        await axios.post('/api/save_word_list', {
          language_1: langs[0],
          language_2: langs[1],
          words: validWords.map(word => ({
            word_language_1: word.word1.trim(),
            word_language_2: word.word2.trim()
          }))
        })

        message.value = 'Changes saved successfully!'
        messageType.value = 'success'
        
        // Reload to get the fresh data
        setTimeout(() => {
          loadWordList()
        }, 1000)
      } catch (error) {
        console.error('Error saving changes:', error)
        message.value = 'Error saving changes'
        messageType.value = 'error'
      } finally {
        saving.value = false
      }
    }

    // Load default list on mount
    loadWordList()

    return {
      selectedList,
      words,
      loading,
      saving,
      message,
      messageType,
      language1,
      language2,
      loadWordList,
      addNewWord,
      deleteWord,
      saveChanges
    }
  }
}
</script>

<style scoped>
.word-lists-tab {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.word-lists-tab h2 {
  color: #667eea;
  margin-bottom: 2rem;
  font-size: 2rem;
}

.language-selector {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  margin-bottom: 2rem;
}

.form-group {
  margin-bottom: 0;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
  color: #495057;
}

.language-select {
  width: 100%;
  max-width: 400px;
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

.list-selector-with-flags {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.flag-pair {
  display: flex;
  gap: 0.5rem;
}

.flag-icon {
  width: 40px;
  height: 30px;
  object-fit: cover;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.loading {
  text-align: center;
  padding: 3rem;
  color: #667eea;
  font-size: 1.2rem;
}

.word-list-container {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.word-list-header {
  display: grid;
  grid-template-columns: 1fr 1fr 80px;
  gap: 1rem;
  padding: 1rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  margin-bottom: 1rem;
  font-weight: 600;
  color: #495057;
}

.column-header {
  text-align: left;
}

.actions-header {
  text-align: center;
}

.word-list-rows {
  max-height: 500px;
  overflow-y: auto;
  margin-bottom: 1.5rem;
}

.word-row {
  display: grid;
  grid-template-columns: 1fr 1fr 80px;
  gap: 1rem;
  padding: 0.75rem 0;
  border-bottom: 1px solid #e0e0e0;
  align-items: center;
}

.word-row:last-child {
  border-bottom: none;
}

.word-input {
  padding: 0.5rem 0.75rem;
  border: 2px solid #e0e0e0;
  border-radius: 6px;
  font-size: 1rem;
  transition: border-color 0.3s ease;
}

.word-input:focus {
  outline: none;
  border-color: #667eea;
}

.delete-button {
  background: #dc3545;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 0.5rem;
  cursor: pointer;
  font-size: 1.2rem;
  transition: all 0.3s ease;
}

.delete-button:hover {
  background: #c82333;
  transform: scale(1.1);
}

.actions {
  display: flex;
  gap: 1rem;
  margin-top: 1.5rem;
}

.action-button {
  padding: 1rem 2rem;
  font-size: 1.1rem;
  font-weight: 600;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s ease;
  flex: 1;
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
  transform: translateY(-2px);
}

.message {
  margin-top: 1rem;
  padding: 1rem;
  border-radius: 6px;
  font-weight: 500;
  text-align: center;
}

.message.success {
  background-color: #d4edda;
  color: #155724;
}

.message.error {
  background-color: #f8d7da;
  color: #721c24;
}

.no-words {
  text-align: center;
  padding: 3rem;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.no-words p {
  font-size: 1.2rem;
  color: #6c757d;
  margin-bottom: 1.5rem;
}
</style>
