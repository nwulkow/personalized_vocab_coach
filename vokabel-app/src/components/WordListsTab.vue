<template>
  <div class="word-lists-tab">
    <h2>Vocabulary Lists</h2>
    <div class="word-count" v-if="!loading">
      Total words: {{ words.length }} | loading: {{ loading }} | list: {{ selectedList }}
    </div>
    
    <div class="language-selector">
      <div class="form-group">
        <label>Select Word List:</label>
        <div class="list-selector-with-flags">
          <div class="flag-pair">
            <img :src="`/${selectedList.split('_')[0]}.png`" :alt="selectedList.split('_')[0]" class="flag-icon" />
            <img :src="`/${selectedList.split('_')[1]}.png`" :alt="selectedList.split('_')[1]" class="flag-icon" />
          </div>
          <select v-model="selectedList" @change="loadWordList" class="language-select">
            <option v-for="list in availableLists" :key="list.key" :value="list.key">
              {{ list.label }}
            </option>
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
        <div class="column-header">Tags</div>
        <div class="column-header date-header">Date Added</div>
        <div class="column-header actions-header">Actions</div>
      </div>

      <div class="word-list-rows">
        <div v-for="(word, index) in words" :key="index" class="word-row">
          <input 
            v-model="word.word1" 
            class="word-input"
            :placeholder="`${language1} word`"
            :ref="el => setWord1Ref(el, index)"
          />
          <input 
            v-model="word.word2" 
            class="word-input"
            :placeholder="`${language2} word`"
          />
          <div class="tags-cell">
            <div class="tag-chips" v-if="parseTags(word.tags).length > 0">
              <span v-for="tag in parseTags(word.tags)" :key="tag" class="tag-chip">
                {{ tag }}
                <button @click="removeTag(word, tag)" class="remove-tag-btn" type="button">✕</button>
              </span>
            </div>
            <div class="tag-input-row" style="position:relative">
              <input
                v-model="word.newTagInput"
                @keydown.enter.stop.prevent="addTagToWord(word)"
                @keydown.escape="word.newTagInput = ''"
                @input="word.showSuggestions = true"
                @blur="delayHideSuggestions(word)"
                @focus="word.showSuggestions = true"
                placeholder="Add tag..."
                class="tag-input"
                type="text"
                autocomplete="off"
              />
              <button @click="addTagToWord(word)" class="add-tag-btn" type="button" :disabled="!word.newTagInput || !word.newTagInput.trim()">+</button>
              <div
                v-if="word.showSuggestions && tagSuggestions(word).length > 0"
                class="tag-suggestions"
              >
                <button
                  v-for="s in tagSuggestions(word)"
                  :key="s"
                  class="tag-suggestion-item"
                  type="button"
                  @mousedown.prevent="selectSuggestion(word, s)"
                >{{ s }}</button>
              </div>
            </div>
          </div>
          <div class="date-display">
            {{ word.date_added || 'N/A' }}
          </div>
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
import { ref, nextTick, onMounted } from 'vue'
import axios from 'axios'

export default {
  name: 'WordListsTab',
  setup() {
    const availableLists = ref([])
    const selectedList = ref('')
    const words = ref([])
    const loading = ref(false)
    const saving = ref(false)
    const message = ref('')
    const messageType = ref('success')
    const language1 = ref('German')
    const language2 = ref('English')
    const word1Refs = ref([])
    const allTags = ref([]) // all unique tags in the current word list

    const setWord1Ref = (el, index) => {
      if (!el) return
      word1Refs.value[index] = el
    }

    const formatLocalDateTime = (d = new Date()) => {
      const pad = (n) => n.toString().padStart(2, '0')
      const year = d.getFullYear()
      const month = pad(d.getMonth() + 1)
      const day = pad(d.getDate())
      const hour = pad(d.getHours())
      const minute = pad(d.getMinutes())
      return `${year}-${month}-${day} ${hour}:${minute}`
    }

    const getLanguagesFromList = (listName) => {
      const parts = listName.split('_')
      return {
        lang1: parts[0].charAt(0).toUpperCase() + parts[0].slice(1),
        lang2: parts[1].charAt(0).toUpperCase() + parts[1].slice(1)
      }
    }

    const fetchAvailableLists = async () => {
      try {
        const response = await axios.get('/api/word_lists')
        availableLists.value = response.data.word_lists || []
        if (availableLists.value.length > 0 && !selectedList.value) {
          selectedList.value = availableLists.value[0].key
        }
        await loadWordList()
      } catch (error) {
        console.error('Error fetching available word lists:', error)
      }
    }

    const parseTags = (tagsStr) => {
      if (!tagsStr || tagsStr === 'NaN') return []
      return tagsStr.split(';').map(t => t.trim()).filter(Boolean)
    }

    const loadWordList = async () => {
      if (!selectedList.value) return
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

        // Reset refs and transform the data to editable format
        console.log('[WordListsTab] API response words count:', response.data.words?.length, 'langs:', langs)
        word1Refs.value = []
        words.value = response.data.words.map(word => ({
          word1: word[langs.lang1] || '',
          word2: word[langs.lang2] || '',
          date_added: word.date_added || '',
          tags: word.tags || '',
          newTagInput: '',
          showSuggestions: false
        }))
        console.log('[WordListsTab] words.value set, length:', words.value.length)
      } catch (error) {
        console.error('Error loading word list:', error)
        message.value = 'Error loading word list'
        messageType.value = 'error'
        words.value = []
      } finally {
        loading.value = false
      }

      // Collect all unique tags for autocomplete — separately so it never clears words
      try {
        const tagSet = new Set()
        words.value.forEach(w => {
          parseTags(w.tags).forEach(t => tagSet.add(t))
        })
        allTags.value = Array.from(tagSet).sort()
      } catch (e) {
        console.warn('Could not collect tags for autocomplete:', e)
      }
    }

    const addNewWord = async () => {
      const dateAdded = formatLocalDateTime(new Date())
      words.value.push({
        word1: '',
        word2: '',
        date_added: dateAdded,
        tags: '',
        newTagInput: '',
        showSuggestions: false
      })

      await nextTick()
      const idx = words.value.length - 1
      const el = word1Refs.value[idx]
      if (el && typeof el.focus === 'function') {
        el.focus()
      }
    }

    const tagSuggestions = (word) => {
      const input = (word.newTagInput || '').trim().toLowerCase()
      if (!input) return []
      const existing = parseTags(word.tags)
      return allTags.value.filter(t =>
        t.toLowerCase().startsWith(input) && !existing.includes(t)
      )
    }

    const selectSuggestion = (word, tag) => {
      word.newTagInput = tag
      word.showSuggestions = false
      addTagToWord(word)
    }

    const delayHideSuggestions = (word) => {
      setTimeout(() => { word.showSuggestions = false }, 150)
    }

    const addTagToWord = (word) => {
      const raw = (word.newTagInput || '').trim()
      if (!raw) return
      const newTags = raw.split(',').map(t => t.trim()).filter(Boolean)
      const existing = parseTags(word.tags)
      for (const tag of newTags) {
        if (!existing.includes(tag)) existing.push(tag)
        if (!allTags.value.includes(tag)) allTags.value.push(tag)
      }
      word.tags = existing.join(';')
      word.newTagInput = ''
      word.showSuggestions = false
    }

    const removeTag = (word, tag) => {
      const existing = parseTags(word.tags).filter(t => t !== tag)
      word.tags = existing.join(';')
    }

    const deleteWord = (index) => {
      if (confirm('Are you sure you want to delete this word pair?')) {
        words.value.splice(index, 1)
        // keep refs array in sync
        if (word1Refs.value && word1Refs.value.length > index) {
          word1Refs.value.splice(index, 1)
        }
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
            word_language_2: word.word2.trim(),
            date_added: word.date_added || '',
            tags: word.tags || ''
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

    // Load available lists on mount
    onMounted(fetchAvailableLists)

    return {
      availableLists,
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
      saveChanges,
      setWord1Ref,
      parseTags,
      addTagToWord,
      removeTag,
      tagSuggestions,
      selectSuggestion,
      delayHideSuggestions
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
  grid-template-columns: 1fr 1fr 180px 130px 60px;
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

.date-header {
  text-align: center;
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
  grid-template-columns: 1fr 1fr 180px 130px 60px;
  gap: 1rem;
  padding: 0.75rem 0;
  border-bottom: 1px solid #e0e0e0;
  align-items: start;
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

.date-display {
  padding: 0.5rem 0.75rem;
  text-align: center;
  color: #6c757d;
  font-size: 0.9rem;
  background-color: #f8f9fa;
  border-radius: 6px;
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
  align-self: start;
  margin-top: 0.25rem;
}

.tags-cell { display: flex; flex-direction: column; gap: 0.35rem; }
.tag-chips { display: flex; flex-wrap: wrap; gap: 0.3rem; }
.tag-chip { display:inline-flex; align-items:center; gap:0.2rem; padding:0.2rem 0.55rem; background:#e8ecff; border-radius:20px; font-size:0.8rem; color:#4a5bbd; }
.remove-tag-btn { background:none; border:none; color:#4a5bbd; cursor:pointer; font-size:0.75rem; padding:0; line-height:1; }
.tag-input-row { display:flex; gap:0.3rem; align-items:center; }
.tag-input { flex:1; padding:0.3rem 0.5rem; border:1px solid #e0e0e0; border-radius:6px; font-size:0.82rem; min-width:0; }
.tag-input:focus { outline:none; border-color:#667eea; }
.add-tag-btn { padding:0.3rem 0.55rem; background:#667eea; color:white; border:none; border-radius:6px; font-size:0.82rem; cursor:pointer; flex-shrink:0; }
.add-tag-btn:disabled { opacity:0.4; cursor:not-allowed; }

.tag-suggestions {
  position: absolute;
  top: calc(100% + 2px);
  left: 0;
  right: 2.4rem;
  background: white;
  border: 2px solid #667eea;
  border-radius: 6px;
  z-index: 100;
  box-shadow: 0 4px 12px rgba(0,0,0,0.12);
  max-height: 160px;
  overflow-y: auto;
}

.tag-suggestion-item {
  display: block;
  width: 100%;
  padding: 0.35rem 0.65rem;
  background: none;
  border: none;
  text-align: left;
  font-size: 0.83rem;
  color: #333;
  cursor: pointer;
}
.tag-suggestion-item:hover { background: #f0f4ff; color: #667eea; }

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
