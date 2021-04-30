// Copyright 2020 Authors of Cilium
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package install

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/cilium/cilium-cli/internal/utils"
)

type azureVersionValidation struct{}

func (m *azureVersionValidation) Name() string {
	return "az-binary"
}

func (m *azureVersionValidation) Check(ctx context.Context, k *K8sInstaller) error {
	_, err := utils.Exec(k.Log, "az", "version", "--output", "json")
	if err != nil {
		return err
	}

	k.Log("✅ Detected az binary")

	return nil
}

type azurePrincipalOutput struct {
	AppID       string `json:"appId"`
	DisplayName string `json:"displayName"`
	Name        string `json:"name"`
	Password    string `json:"password"`
	Tenant      string `json:"tenant"`
}

type aksClusterInfo struct {
	NodeResourceGroup string `json:"nodeResourceGroup"`
}

type accountInfo struct {
	ID string `json:"id"`
}

func (k *K8sInstaller) createAzureServicePrincipal(ctx context.Context) error {
	if k.params.Azure.TenantID == "" {
		k.Log("🚀 Creating service principal for Cilium operator...")
		bytes, err := utils.Exec(k.Log, "az", "ad", "sp", "create-for-rbac", "--output", "json")
		if err != nil {
			return err
		}

		p := azurePrincipalOutput{}
		if err := json.Unmarshal(bytes, &p); err != nil {
			return fmt.Errorf("unable to unmarshal az output: %w", err)
		}

		k.Log("✅ Created service principal for cilium operator with App ID %s and tenant ID %s", p.AppID, p.Tenant)
		k.params.Azure.TenantID = p.Tenant
		k.params.Azure.ClientID = p.AppID
		k.params.Azure.ClientSecret = p.Password
	} else {
		k.Log("✅ Using manually configured principal for cilium operator with App ID %s and tenant ID %s",
			k.params.Azure.ClientID, k.params.Azure.TenantID)
	}

	bytes, err := utils.Exec(k.Log, "az", "account", "show", "--output", "json")
	if err != nil {
		return err
	}

	ai := accountInfo{}
	if err := json.Unmarshal(bytes, &ai); err != nil {
		return fmt.Errorf("unable to unmarshal az output: %w", err)
	}

	k.Log("✅ Derived Azure subscription id %s", ai.ID)
	k.params.Azure.SubscriptionID = ai.ID

	bytes, err = utils.Exec(k.Log, "az", "aks", "show", "--resource-group", k.params.Azure.ResourceGroupName, "--name", k.params.ClusterName, "--output", "json")
	if err != nil {
		return err
	}

	clusterInfo := aksClusterInfo{}
	if err := json.Unmarshal(bytes, &clusterInfo); err != nil {
		return fmt.Errorf("unable to unmarshal az output: %w", err)
	}

	k.Log("✅ Derived Azure node resource group %s", clusterInfo.NodeResourceGroup)
	k.params.Azure.ResourceGroup = clusterInfo.NodeResourceGroup

	return nil
}
