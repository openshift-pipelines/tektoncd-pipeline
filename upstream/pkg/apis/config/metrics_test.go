/*
Copyright 2021 The Tekton Authors

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

package config_test

import (
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/tektoncd/pipeline/pkg/apis/config"
	test "github.com/tektoncd/pipeline/pkg/reconciler/testing"
	"github.com/tektoncd/pipeline/test/diff"
)

func TestNewMetricsFromConfigMap(t *testing.T) {
	type testCase struct {
		expectedConfig *config.Metrics
		fileName       string
	}

	testCases := []testCase{
		{
			expectedConfig: &config.Metrics{
				TaskrunLevel:            config.TaskrunLevelAtTaskrun,
				PipelinerunLevel:        config.PipelinerunLevelAtPipelinerun,
				RunningPipelinerunLevel: config.DefaultRunningPipelinerunLevel,
				DurationTaskrunType:     config.DurationPipelinerunTypeHistogram,
				DurationPipelinerunType: config.DurationPipelinerunTypeHistogram,
				CountWithReason:         false,
				ThrottleWithNamespace:   false,
			},
			fileName: config.GetMetricsConfigName(),
		},
		{
			expectedConfig: &config.Metrics{
				TaskrunLevel:            config.TaskrunLevelAtNS,
				PipelinerunLevel:        config.PipelinerunLevelAtNS,
				RunningPipelinerunLevel: config.PipelinerunLevelAtNS,
				DurationTaskrunType:     config.DurationTaskrunTypeHistogram,
				DurationPipelinerunType: config.DurationPipelinerunTypeLastValue,
				CountWithReason:         false,
				ThrottleWithNamespace:   false,
			},
			fileName: "config-observability-namespacelevel",
		},
		{
			expectedConfig: &config.Metrics{
				TaskrunLevel:            config.TaskrunLevelAtNS,
				PipelinerunLevel:        config.PipelinerunLevelAtNS,
				RunningPipelinerunLevel: config.DefaultRunningPipelinerunLevel,
				DurationTaskrunType:     config.DurationTaskrunTypeHistogram,
				DurationPipelinerunType: config.DurationPipelinerunTypeLastValue,
				CountWithReason:         true,
				ThrottleWithNamespace:   false,
			},
			fileName: "config-observability-reason",
		},
		{
			expectedConfig: &config.Metrics{
				TaskrunLevel:            config.TaskrunLevelAtNS,
				PipelinerunLevel:        config.PipelinerunLevelAtNS,
				RunningPipelinerunLevel: config.PipelinerunLevelAtPipeline,
				DurationTaskrunType:     config.DurationTaskrunTypeHistogram,
				DurationPipelinerunType: config.DurationPipelinerunTypeLastValue,
				CountWithReason:         true,
				ThrottleWithNamespace:   true,
			},
			fileName: "config-observability-throttle",
		},
	}

	for _, tc := range testCases {
		verifyConfigFileWithExpectedMetricsConfig(t, tc.fileName, tc.expectedConfig)
	}
}

func TestNewMetricsFromEmptyConfigMap(t *testing.T) {
	MetricsConfigEmptyName := "config-observability-empty"
	expectedConfig := &config.Metrics{
		TaskrunLevel:            config.TaskrunLevelAtTask,
		PipelinerunLevel:        config.PipelinerunLevelAtPipeline,
		RunningPipelinerunLevel: config.DefaultRunningPipelinerunLevel,
		DurationTaskrunType:     config.DurationPipelinerunTypeHistogram,
		DurationPipelinerunType: config.DurationPipelinerunTypeHistogram,
		CountWithReason:         false,
		ThrottleWithNamespace:   false,
	}
	verifyConfigFileWithExpectedMetricsConfig(t, MetricsConfigEmptyName, expectedConfig)
}

func verifyConfigFileWithExpectedMetricsConfig(t *testing.T, fileName string, expectedConfig *config.Metrics) {
	t.Helper()
	cm := test.ConfigMapFromTestFile(t, fileName)
	if ab, err := config.NewMetricsFromConfigMap(cm); err == nil {
		if d := cmp.Diff(expectedConfig, ab); d != "" {
			t.Errorf("Diff:\n%s", diff.PrintWantGot(d))
		}
	} else {
		t.Errorf("NewMetricsFromConfigMap(actual) = %v", err)
	}
}
