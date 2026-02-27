<template>
  <div class="translator-tab">
    <div class="translation-list">
      <div v-for="(item, index) in translationItems" :key="index" class="translation-item">
        <div class="translation-row">
          <div class="input-group">
            <div class="language-selector">
              <img :src="`/${item.srcLanguage}.png`" :alt="item.srcLanguage" class="flag-icon" />
              <select v-model="item.srcLanguage" class="language-select">
                <option value="german">German</option>
                <option value="english">English</option>
                <option value="spanish">Spanish</option>
                <option value="french">French</option>
              </select>
            </div>
            <textarea 
              v-model="item.sourceText" 
              @click="selectText($event)" 
              @input="setLastEditedField(index, 'source')"
              @keydown.enter.exact.prevent="handleEnterKey(index, 'source')"
              placeholder="Enter text to translate..." 
              class="text-input" 
              rows="3"
            ></textarea>
          </div>

          <div class="button-group">
            <button @click="swapLanguages(index)" class="swap-button" title="Swap languages" type="button">⇄</button>
            <button @click="translateItem(index)" class="translate-button" :disabled="!item.sourceText.trim()" type="button">→<br/>Translate</button>
          </div>

          <div class="input-group">
            <div class="language-selector">
              <img :src="`/${item.destLanguage}.png`" :alt="item.destLanguage" class="flag-icon" />
              <select v-model="item.destLanguage" class="language-select">
                <option value="german">German</option>
                <option value="english">English</option>
                <option value="spanish">Spanish</option>
                <option value="french">French</option>
              </select>
            </div>
            <div class="translation-output-row">
              <textarea 
                v-model="item.translatedText" 
                @click="selectText($event)" 
                @input="setLastEditedField(index, 'translated')"
                @keydown.enter.exact.prevent="handleEnterKey(index, 'translated')"
                placeholder="Translation will appear here..." 
                class="text-input readonly" 
                rows="3" 
                readonly
              ></textarea>
              <button
                @click="showAlternatives(index)"
                class="alternatives-button"
                :disabled="!item.translatedText.trim() || item.loadingAlternatives"
                type="button"
                title="Show alternative translations"
              >{{ item.loadingAlternatives ? '⏳' : 'Show\nalternatives' }}</button>
            </div>
            <div v-if="item.alternatives && item.alternatives.length > 0" class="alternatives-row">
              <button
                v-for="(alt, altIndex) in item.alternatives"
                :key="altIndex"
                @click="selectAlternative(index, alt)"
                class="alternative-button"
                type="button"
              >{{ alt }}</button>
            </div>
          </div>
        </div>

        <div class="voice-option">
          <label><input type="checkbox" v-model="item.speakTranslated" /> Enable voice for translation</label>
        </div>
      </div>
    </div>

    <div class="actions">
      <div v-if="successMessage" class="success-message">
        {{ successMessage }}
      </div>
      <button @click="addWordToList" class="action-button primary" type="button">➕ Add to Word List</button>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue'
import axios from 'axios'

export default {
  name: 'TranslatorTab',
  setup() {
    const translationItems = ref([
      { srcLanguage: 'german', destLanguage: 'english', sourceText: '', translatedText: '', speakTranslated: false, alternatives: [], loadingAlternatives: false },
      { srcLanguage: 'german', destLanguage: 'spanish', sourceText: '', translatedText: '', speakTranslated: false, alternatives: [], loadingAlternatives: false },
      { srcLanguage: 'german', destLanguage: 'french', sourceText: '', translatedText: '', speakTranslated: false, alternatives: [], loadingAlternatives: false }
    ])

    const lastEditedField = ref({ index: 0, field: 'source' })
    const successMessage = ref('')

    const selectText = (event) => {
      // Use setTimeout to ensure selection happens after the click event completes
      setTimeout(() => {
        event.target.select()
      }, 0)
    }

    const setLastEditedField = (index, field) => {
      lastEditedField.value = { index, field }
    }

    const handleEnterKey = (index, field) => {
      // Translate in the direction of the last edited field
      if (field === 'source') {
        translateItem(index)
      } else if (field === 'translated') {
        // If user edited translated field, translate back (swap first)
        swapLanguages(index)
        translateItem(index)
      }
    }

    const translateItem = async (index) => {
      const item = translationItems.value[index]
      if (!item.sourceText.trim()) return
      try {
        const response = await axios.post('/api/translate', null, {
          params: {
            text: item.sourceText,
            src_language: item.srcLanguage,
            dest_language: item.destLanguage,
            speak_translated: item.speakTranslated
          }
        })
        item.translatedText = response.data.translated_text
        item.alternatives = []
        // Track that this item was translated
        lastEditedField.value = { index, field: 'source' }
      } catch (err) {
        console.error('Translation error:', err)
        alert('Error translating text. Make sure the API server is running.')
      }
    }

    const swapLanguages = (index) => {
      const item = translationItems.value[index]
      const tmpLang = item.srcLanguage
      item.srcLanguage = item.destLanguage
      item.destLanguage = tmpLang
      const tmpText = item.sourceText
      item.sourceText = item.translatedText
      item.translatedText = tmpText
    }

    const showAlternatives = async (index) => {
      const item = translationItems.value[index]
      if (!item.translatedText.trim()) return
      item.loadingAlternatives = true
      item.alternatives = []
      try {
        const response = await axios.post('/api/show_alternatives', null, {
          params: {
            word: item.sourceText,
            src_language: item.srcLanguage,
            dest_language: item.destLanguage,
            google_translation: item.translatedText
          }
        })
        item.alternatives = response.data.alternatives
      } catch (err) {
        console.error('Error fetching alternatives:', err)
        alert('Error fetching alternatives. Make sure the API server is running.')
      } finally {
        item.loadingAlternatives = false
      }
    }

    const selectAlternative = (index, alt) => {
      translationItems.value[index].translatedText = alt
      translationItems.value[index].alternatives = []
    }

    const addWordToList = async () => {
      // Use the last edited item instead of just finding the first valid one
      const lastIndex = lastEditedField.value.index
      const validItem = translationItems.value[lastIndex]
      
      // Check if the last edited item has both texts filled
      if (!validItem.sourceText.trim() || !validItem.translatedText.trim()) {
        alert('Please translate the text before adding to word list.')
        return
      }
      
      try {
        const lang1 = validItem.srcLanguage.charAt(0).toUpperCase() + validItem.srcLanguage.slice(1)
        const lang2 = validItem.destLanguage.charAt(0).toUpperCase() + validItem.destLanguage.slice(1)
        
        await axios.post('/api/add_word_pair', null, { params: {
          word_language_1: validItem.sourceText,
          word_language_2: validItem.translatedText,
          language_1: validItem.srcLanguage,
          language_2: validItem.destLanguage
        }})
        
        // Show detailed success message
        successMessage.value = `Added "${validItem.sourceText}" → "${validItem.translatedText}" to ${lang1}/${lang2} word list`
        
        // Auto-hide message after 2 seconds
        setTimeout(() => {
          successMessage.value = ''
        }, 2000)
      } catch (err) {
        console.error('Error adding word pair:', err)
        alert('Error adding word pair to list. Make sure the API server is running.')
      }
    }

    return { 
      translationItems, 
      lastEditedField, 
      successMessage,
      translateItem, 
      swapLanguages, 
      addWordToList,
      showAlternatives,
      selectAlternative,
      selectText,
      setLastEditedField,
      handleEnterKey
    }
  }
}
</script>

<style scoped>
.translator-tab { max-width: 1400px; margin: 0 auto; }
.translation-list { display:flex; flex-direction:column; gap:2rem; margin-bottom:2rem }
.translation-item { background:white; border-radius:12px; padding:1.5rem; box-shadow:0 4px 6px rgba(0,0,0,0.1) }
.translation-row { display:grid; grid-template-columns: 1fr auto 1fr; gap:1.5rem; align-items:center }
.button-group { display:flex; flex-direction:column; gap:0.5rem; align-items:center }
.input-group { display:flex; flex-direction:column; gap:0.5rem }
.input-group label { font-weight:600; color:#667eea; font-size:0.9rem; text-transform:capitalize }
.language-selector { display:flex; align-items:center; gap:0.75rem }
.flag-icon { width:32px; height:24px; object-fit:cover; border-radius:4px; box-shadow:0 2px 4px rgba(0,0,0,0.1) }
.language-select { padding:0.5rem; border:2px solid #e0e0e0; border-radius:6px; font-size:1rem; background:white; cursor:pointer }
.language-select:focus { outline:none; border-color:#667eea }
.text-input { width:100%; padding:0.75rem; border:2px solid #e0e0e0; border-radius:6px; font-size:1rem; font-family:inherit; resize:vertical }
.text-input:focus { outline:none; border-color:#667eea }
.text-input.readonly { background:#f8f9fa; cursor:default }
.translation-output-row { display:flex; gap:0.5rem; align-items:flex-start }
.translation-output-row .text-input { flex:1 }
.alternatives-button { padding:0.5rem 0.6rem; background:linear-gradient(135deg,#764ba2 0%,#667eea 100%); color:white; border:none; border-radius:6px; font-size:0.78rem; font-weight:600; cursor:pointer; white-space:pre-line; line-height:1.4; flex-shrink:0; align-self:stretch }
.alternatives-button:disabled { opacity:0.5; cursor:not-allowed }
.alternatives-button:not(:disabled):hover { transform:scale(1.03) }
.alternatives-row { display:flex; flex-wrap:wrap; gap:0.5rem; margin-top:0.75rem }
.alternative-button { padding:0.4rem 0.85rem; background:white; color:#667eea; border:2px solid #667eea; border-radius:6px; font-size:0.9rem; cursor:pointer; transition:background 0.15s, color 0.15s }
.alternative-button:hover { background:#667eea; color:white }
.swap-button { padding:0.5rem 1rem; background:#6c757d; color:white; border:none; border-radius:6px; font-size:1.5rem; font-weight:600; cursor:pointer }
.swap-button:hover { background:#5a6268; transform:scale(1.03) }
.translate-button { padding:1rem 1.5rem; background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); color:white; border:none; border-radius:8px; font-size:1rem; font-weight:600; cursor:pointer; align-self:center }
.translate-button:disabled { opacity:0.5; cursor:not-allowed }
.voice-option { margin-top:1rem; padding-top:1rem; border-top:1px solid #e0e0e0 }
.voice-option label { display:flex; align-items:center; gap:0.5rem; font-size:0.9rem; color:#667eea }
.voice-option input[type="checkbox"] { width:16px; height:16px }
.actions { display:flex; justify-content:flex-end; align-items:center; gap:1rem; padding-top:1rem }
.action-button { padding:1rem 2rem; font-size:1.1rem; font-weight:600; border:none; border-radius:8px; cursor:pointer }
.action-button.primary { background:linear-gradient(135deg,#28a745 0%,#20c997 100%); color:white }
.action-button.primary:hover { transform:translateY(-2px) }
.success-message {
  padding: 0.75rem 1.25rem;
  background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%);
  color: #155724;
  border-radius: 8px;
  font-weight: 600;
  box-shadow: 0 2px 8px rgba(21, 87, 36, 0.2);
  animation: slideIn 0.3s ease-out;
  white-space: nowrap;
}
@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateX(-10px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}
@media (max-width:768px) {
  .translation-row { grid-template-columns:1fr; gap:1rem }
  .button-group { flex-direction:row; width:100%; gap:0.5rem }
  .swap-button, .translate-button { flex:1 }
  .actions { flex-direction: column-reverse; align-items: stretch; }
  .success-message { white-space: normal; text-align: center; }
}
</style>
            .action-button.primary { background:linear-gradient(135deg,#28a745 0%,#20c997 100%); color:white }
