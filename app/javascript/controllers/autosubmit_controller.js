import { Controller } from "@hotwired/stimulus"

// Submits the surrounding form when a control changes, so selects can
// navigate without a dedicated button.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
