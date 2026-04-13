<template>
  <div class="app">
    <header>
      <h1>🎓 Vokabeltrainer</h1>
      <div class="llm-badge">🤖 {{ llmDisplay }}</div>
    </header>
    
    <div class="tabs">
      <button 
        class="tab-button" 
        :class="{ active: activeTab === 'translator' }"
        @click="activeTab = 'translator'"
      >
        Translator
      </button>
      <button 
        class="tab-button" 
        :class="{ active: activeTab === 'vocabulary' }"
        @click="activeTab = 'vocabulary'"
      >
        Vocabulary Testing
      </button>
      <button 
        class="tab-button" 
        :class="{ active: activeTab === 'wordlists' }"
        @click="activeTab = 'wordlists'"
      >
        Word Lists
      </button>
    </div>

    <div class="tab-content">
      <TranslatorTab v-if="activeTab === 'translator'" />
      <VocabularyTab v-if="activeTab === 'vocabulary'" />
      <WordListsTab v-if="activeTab === 'wordlists'" />
    </div>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import TranslatorTab from './components/TranslatorTab.vue'
import VocabularyTab from './components/VocabularyTab.vue'
import WordListsTab from './components/WordListsTab.vue'

export default {
  name: 'App',
  components: {
    TranslatorTab,
    VocabularyTab,
    WordListsTab
  },
  setup() {
    const activeTab = ref('translator')
    const llmDisplay = ref('No LLM active')

    onMounted(async () => {
      try {
        const res = await fetch('http://localhost:8000/llm_info')
        const data = await res.json()
        llmDisplay.value = data.display || 'No LLM active'
      } catch {
        llmDisplay.value = 'No LLM active'
      }
    })

    return {
      activeTab,
      llmDisplay
    }
  }
}
</script>

<style scoped>
.app {
  min-height: 100vh;
}

header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem;
  text-align: center;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

header h1 {
  margin: 0;
  font-size: 2.5rem;
  font-weight: 600;
}

.llm-badge {
  margin-top: 0.5rem;
  display: inline-block;
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.35);
  border-radius: 20px;
  padding: 0.25rem 0.85rem;
  font-size: 0.85rem;
  font-weight: 500;
  letter-spacing: 0.02em;
}

.tabs {
  display: flex;
  justify-content: center;
  gap: 1rem;
  padding: 2rem 1rem 0;
  background-color: #f8f9fa;
}

.tab-button {
  padding: 0.75rem 2rem;
  font-size: 1.1rem;
  font-weight: 500;
  border: none;
  background-color: white;
  color: #667eea;
  border-radius: 8px 8px 0 0;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.tab-button:hover {
  background-color: #f0f4ff;
  transform: translateY(-2px);
}

.tab-button.active {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.15);
}

.tab-content {
  background-color: #f8f9fa;
  min-height: calc(100vh - 200px);
  padding: 2rem;
}
</style>
