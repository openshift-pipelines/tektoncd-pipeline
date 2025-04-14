/*
Copyright The Kubernetes Authors.

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

// Code generated by applyconfiguration-gen. DO NOT EDIT.

package v1

import (
	v1 "k8s.io/api/core/v1"
	resource "k8s.io/apimachinery/pkg/api/resource"
)

// EmptyDirVolumeSourceApplyConfiguration represents a declarative configuration of the EmptyDirVolumeSource type for use
// with apply.
type EmptyDirVolumeSourceApplyConfiguration struct {
	Medium    *v1.StorageMedium  `json:"medium,omitempty"`
	SizeLimit *resource.Quantity `json:"sizeLimit,omitempty"`
}

// EmptyDirVolumeSourceApplyConfiguration constructs a declarative configuration of the EmptyDirVolumeSource type for use with
// apply.
func EmptyDirVolumeSource() *EmptyDirVolumeSourceApplyConfiguration {
	return &EmptyDirVolumeSourceApplyConfiguration{}
}

// WithMedium sets the Medium field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the Medium field is set to the value of the last call.
func (b *EmptyDirVolumeSourceApplyConfiguration) WithMedium(value v1.StorageMedium) *EmptyDirVolumeSourceApplyConfiguration {
	b.Medium = &value
	return b
}

// WithSizeLimit sets the SizeLimit field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the SizeLimit field is set to the value of the last call.
func (b *EmptyDirVolumeSourceApplyConfiguration) WithSizeLimit(value resource.Quantity) *EmptyDirVolumeSourceApplyConfiguration {
	b.SizeLimit = &value
	return b
}
