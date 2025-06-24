package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-sdk-go-v2/service/ssm/types"
)

type Input struct {
	BasePath   string      `json:"base_path"`
	Parameters []Parameter `json:"parameters"`
}

type Parameter struct {
	Path        string `json:"path"`
	Value       string `json:"value"`
	Type        string `json:"type"`
	Tier        string `json:"tier"`
	Description string `json:"description"`
}

var overwrite bool = true
var client *ssm.Client

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("Failed to load AWS config: %v", err)
	}
	client = ssm.NewFromConfig(cfg)
}

func main() {
	var inputPath string
	flag.StringVar(&inputPath, "input-path", "", "input path")
	flag.Parse()

	input, err := os.ReadFile(inputPath)
	if err != nil {
		log.Fatalf("Failed to read input file: %v", err)
	}

	var inputData Input
	err = json.Unmarshal(input, &inputData)
	if err != nil {
		log.Fatalf("Failed to unmarshal input: %v", err)
	}

	for _, parameter := range inputData.Parameters {
		path := fmt.Sprintf("%s/%s", inputData.BasePath, parameter.Path)
		output, err := client.PutParameter(context.TODO(), &ssm.PutParameterInput{
			Name:        &path,
			Value:       &parameter.Value,
			Description: &parameter.Description,
			Tier:        types.ParameterTier(parameter.Tier),
			Type:        types.ParameterType(parameter.Type),
			Overwrite:   &overwrite,
		})
		if err != nil {
			log.Fatalf("Failed to put parameter: %v", err)
		}
		log.Printf("Parameter %s upserted: %d", parameter.Path, &output.Version)
	}

}
