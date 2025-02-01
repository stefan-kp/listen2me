import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    this.element.querySelectorAll('.icon-option').forEach(option => {
      const label = option.querySelector('label')
      const icon = option.querySelector('svg')
      
      if (option.querySelector('input').checked) {
        label.classList.add('border-indigo-600', 'bg-indigo-50')
        icon.classList.add('text-indigo-600')
        icon.classList.remove('text-gray-500')
      } else {
        label.classList.remove('border-indigo-600', 'bg-indigo-50')
        icon.classList.remove('text-indigo-600')
        icon.classList.add('text-gray-500')
      }
    })
  }
} 