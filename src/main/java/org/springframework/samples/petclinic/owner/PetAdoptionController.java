/*
 * Copyright 2012-2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.springframework.samples.petclinic.owner;

import org.springframework.stereotype.Controller;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * Controller for pet adoption workflow.
 *
 * @author PetClinic Contributors
 */
@Controller
@RequestMapping("/adoptions")
class PetAdoptionController {

	private final PetRepository pets;

	PetAdoptionController(PetRepository pets) {
		this.pets = pets;
	}

	@GetMapping
	String showAdoptablePets(Model model) {
		model.addAttribute("pets", this.pets.findByAdoptedFalseOrderByNameAsc());
		model.addAttribute("adoptedPets", this.pets.findByAdoptedTrueOrderByNameAsc());
		return "pets/adoptionList";
	}

	@PostMapping("/{petId}/adopt")
	@Transactional
	String adoptPet(@PathVariable("petId") int petId, RedirectAttributes redirectAttributes) {
		Pet pet = this.pets.findById(petId)
			.orElseThrow(() -> new IllegalArgumentException("Pet not found with id: " + petId));

		if (!pet.isAdopted()) {
			pet.setAdopted(true);
			this.pets.save(pet);
			redirectAttributes.addFlashAttribute("adoptedPetName", pet.getName());
		}
		else {
			redirectAttributes.addFlashAttribute("alreadyAdoptedPetName", pet.getName());
		}
		return "redirect:/adoptions";
	}

}
