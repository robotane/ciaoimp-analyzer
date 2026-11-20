/*
Copyright 2026 The hotmoka-gas-bounds authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package io.hotmoka.examples.tontine;

import java.math.BigInteger;

import io.takamaka.code.lang.Event;
import io.takamaka.code.lang.FromContract;
import io.takamaka.code.lang.PayableContract;

public class Adhesion extends Event {
	public final PayableContract membre;

	@FromContract Adhesion(PayableContract membre) {
		this.membre = membre;
	}
}
