package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"

	"github.com/temporalio/temporalite"
	"go.temporal.io/server/common/dynamicconfig"
	serverlog "go.temporal.io/server/common/log"
	"go.temporal.io/server/temporal"
)

func main() {
	log.Printf("Let's do this!")

	if len(os.Args) != 3 {
		log.Fatalf("expected port and namespace args, found %v args", len(os.Args) - 1)
	}

	if err := run(os.Args[1], os.Args[2]); err != nil {
		log.Fatal(err)
	}
}

func run(portStr, namespace string) error {
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return fmt.Errorf("invalid port: %w", err)
	}

	log.Printf("Starting server on port %v for namespace %v", port, namespace)

	// Create a non-TLS server
	server, err := temporalite.NewServer(
		temporalite.WithNamespaces(namespace),
		temporalite.WithPersistenceDisabled(),
		temporalite.WithFrontendPort(port),
		temporalite.WithLogger(serverlog.NewNoopLogger()),
		// This is needed so that tests can run without search attribute cache
		temporalite.WithUpstreamOptions(
			temporal.WithDynamicConfigClient(
				dynamicconfig.NewMutableEphemeralClient(
					dynamicconfig.Set(dynamicconfig.ForceSearchAttributesCacheRefreshOnRead, true)))),
	)
	if err != nil {
		return err
	}

	if err := server.Start(); err != nil {
		return err
	}

	defer server.Stop()
	defer log.Printf("Stopping servers")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM, os.Interrupt)
	<-sigCh

	return nil
}
