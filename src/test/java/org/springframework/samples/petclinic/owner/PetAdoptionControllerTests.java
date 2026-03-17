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

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(PetAdoptionController.class)
@DisabledInNativeImage
@DisabledInAotMode
class PetAdoptionControllerTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private PetRepository pets;

	@Test
	void shouldShowAdoptablePets() throws Exception {
		Pet pet = new Pet();
		pet.setId(1);
		pet.setName("Lucky");
		pet.setBirthDate(LocalDate.of(2020, 1, 1));

		PetType type = new PetType();
		type.setName("dog");
		pet.setType(type);

		given(this.pets.findByAdoptedFalseOrderByNameAsc()).willReturn(List.of(pet));
		given(this.pets.findByAdoptedTrueOrderByNameAsc()).willReturn(List.of());

		this.mockMvc.perform(get("/adoptions"))
			.andExpect(status().isOk())
			.andExpect(view().name("pets/adoptionList"))
			.andExpect(model().attributeExists("pets"))
			.andExpect(model().attributeExists("adoptedPets"));
	}

	@Test
	void shouldAdoptPetAndRedirect() throws Exception {
		Pet pet = new Pet();
		pet.setId(1);
		pet.setName("Lucky");
		pet.setAdopted(false);

		given(this.pets.findById(1)).willReturn(Optional.of(pet));

		this.mockMvc.perform(post("/adoptions/{petId}/adopt", 1))
			.andExpect(status().is3xxRedirection())
			.andExpect(redirectedUrl("/adoptions"));

		verify(this.pets).save(any(Pet.class));
	}

}
