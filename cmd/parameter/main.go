package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"errors"

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
var maxRetries int = 30
var retryDelay time.Duration = 10 * time.Second

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
	var delete bool
	flag.BoolVar(&delete, "delete", false, "delete parameters")
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

	if delete {
		var paramNotFound *types.ParameterNotFound
		var throttleException *types.ThrottlingException
		for _, parameter := range inputData.Parameters {
			path := fmt.Sprintf("%s/%s", inputData.BasePath, parameter.Path)
			_, err := client.DeleteParameter(context.TODO(), &ssm.DeleteParameterInput{
				Name: &path,
			})
			if err == nil {
				log.Printf("Parameter %s deleted", path)
			} else {
				// Verificar si el error es ParameterNotFound
				if errors.As(err, &paramNotFound) {
					log.Printf("Parameter %s not found, skipping retry", path)
					continue
				}

				log.Printf("Failed to delete parameter %s: %v", path, err)
				for i := 0; i < maxRetries; i++ {
					time.Sleep(retryDelay)
					_, err = client.DeleteParameter(context.TODO(), &ssm.DeleteParameterInput{
						Name: &path,
					})
					// Verificar si el error es ThrottlingException
					if errors.As(err, &throttleException) {
						log.Printf("Throttling exception during retry, sleeping for %d seconds", retryDelay/time.Second)
						continue
					}
					break
				}
				if err != nil {
					log.Fatalf("Failed to delete parameter %s: %v", path, err)
				}
			}
		}
		return
	} else {
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
				log.Printf("Failed to put parameter %s: %v", path, err)
				for i := 0; i < maxRetries; i++ {
					time.Sleep(retryDelay)
					_, err = client.PutParameter(context.TODO(), &ssm.PutParameterInput{
						Name:        &path,
						Value:       &parameter.Value,
						Description: &parameter.Description,
						Tier:        types.ParameterTier(parameter.Tier),
						Type:        types.ParameterType(parameter.Type),
						Overwrite:   &overwrite,
					})
					if err == nil {
						break
					}
				}
				if err != nil {
					log.Fatalf("Failed to put parameter %s: %v", path, err)
				}
			}
			log.Printf("Parameter %s upserted: %d", parameter.Path, &output.Version)
		}
	}
}
