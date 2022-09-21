package main

import (
	"fmt"
	"log"
	"os"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

func main() {
	if len(os.Args) != 4 {
		log.Fatalf("expected endpoint, namespace and task queue args, found %v args", len(os.Args)-1)
	}

	if err := run(os.Args[1], os.Args[2], os.Args[3]); err != nil {
		log.Fatal(err)
	}
}

func run(endpoint, namespace, taskQueue string) error {
	log.Printf("Creating client to %v", endpoint)
	cl, err := client.NewClient(client.Options{HostPort: endpoint, Namespace: namespace})
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}
	defer cl.Close()

	log.Printf("Creating worker")
	w := worker.New(cl, taskQueue, worker.Options{})
	w.RegisterWorkflowWithOptions(KitchenSinkWorkflow, workflow.RegisterOptions{Name: "kitchen_sink"})
	defer log.Printf("Stopping worker")

	return w.Run(worker.InterruptCh())
}
