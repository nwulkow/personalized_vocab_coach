<template>
  <div>
    <h1>My Translator & Vocabulary App</h1>
    <button @click="tab = 'translate'">Translate</button>
    <button @click="tab = 'vocab'">Vocabulary Test</button>

    <div v-if="tab === 'translate'">
      <input v-model="inputText" placeholder="Enter text" />
      <button @click="doTranslate">Translate</button>
      <input v-model="translatedText" placeholder="Result" readonly />
    </div>

    <div v-if="tab === 'vocab'">
      <h3>{{ currentWord }}</h3>
      <input
        v-model="userAnswer"
        placeholder="Your translation"
        @keyup.enter="checkAnswer"
      />
      <button @click="checkAnswer">Submit</button>
      <p v-if="feedback">{{ feedback }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue"

const tab = ref("translate")

const inputText = ref("")
const translatedText = ref("")

async function doTranslate() {
  const res = await fetch("http://127.0.0.1:8001/translate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      text: inputText.value,
      src_language: "en",
      dest_language: "de",
      speak_translated: false
    })
  })
  const data = await res.json()
  translatedText.value = data.translated_text
}

// Vocabulary tab
const words = ["hello", "world", "cat"]
const currentWord = ref(words[0])
const userAnswer = ref("")
const feedback = ref("")

async function checkAnswer() {
  const res = await fetch("http://127.0.0.1:8001/check", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      word: currentWord.value,
      answer: userAnswer.value
    })
  })
  const data = await res.json()
  feedback.value = data.correct ? "Correct!" : "Wrong!"
  userAnswer.value = ""
}
</script>
