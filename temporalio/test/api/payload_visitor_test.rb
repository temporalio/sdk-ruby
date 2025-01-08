# frozen_string_literal: true

require 'temporalio/api/payload_visitor'
require 'test_base'

module Api
  class PayloadVisitorTest < TestBase
    def test_basics
      # Make protos that have:
      # * single payload
      # * obj payloads
      # * repeated payloads
      # * map value
      # * search attributes obj
      # * search attributes map
      act = Temporalio::Internal::Bridge::Api::WorkflowActivation::WorkflowActivation.new(
        jobs: [
          Temporalio::Internal::Bridge::Api::WorkflowActivation::WorkflowActivationJob.new(
            initialize_workflow: Temporalio::Internal::Bridge::Api::WorkflowActivation::InitializeWorkflow.new(
              arguments: [
                Temporalio::Api::Common::V1::Payload.new(data: 'repeated1'),
                Temporalio::Api::Common::V1::Payload.new(data: 'repeated2')
              ],
              headers: {
                'header' => Temporalio::Api::Common::V1::Payload.new(data: 'map')
              },
              last_completion_result: Temporalio::Api::Common::V1::Payloads.new(
                payloads: [
                  Temporalio::Api::Common::V1::Payload.new(data: 'obj1'),
                  Temporalio::Api::Common::V1::Payload.new(data: 'obj2')
                ]
              ),
              search_attributes: Temporalio::Api::Common::V1::SearchAttributes.new(
                indexed_fields: { 'sakey' => Temporalio::Api::Common::V1::Payload.new(data: 'saobj') }
              )
            )
          )
        ]
      )
      succ = Temporalio::Internal::Bridge::Api::WorkflowCompletion::Success.new(
        commands: [
          Temporalio::Internal::Bridge::Api::WorkflowCommands::WorkflowCommand.new(
            complete_workflow_execution:
            Temporalio::Internal::Bridge::Api::WorkflowCommands::CompleteWorkflowExecution.new(
              result: Temporalio::Api::Common::V1::Payload.new(data: 'single')
            )
          ),
          Temporalio::Internal::Bridge::Api::WorkflowCommands::WorkflowCommand.new(
            upsert_workflow_search_attributes:
            Temporalio::Internal::Bridge::Api::WorkflowCommands::UpsertWorkflowSearchAttributes.new(
              search_attributes: { 'sakey' => Temporalio::Api::Common::V1::Payload.new(data: 'samap') }
            )
          )
        ]
      )
      mutator = proc do |value|
        case value
        when Temporalio::Api::Common::V1::Payload
          value.data += '-single' # steep:ignore
        when Enumerable
          value.replace( # steep:ignore
            [Temporalio::Api::Common::V1::Payload.new(data: "#{value.map(&:data).join('-')}-repeated")]
          )
        else
          raise 'Unrecognized type'
        end
      end

      # Basic check including search attributes
      visitor = Temporalio::Api::PayloadVisitor.new(&mutator)
      mutated_act = act.class.decode(act.class.encode(act))
      mutated_succ = succ.class.decode(succ.class.encode(succ))
      visitor.run(mutated_act)
      visitor.run(mutated_succ)
      mutated_init = mutated_act.jobs.first.initialize_workflow
      assert_equal 'repeated1-repeated2-repeated', mutated_init.arguments.first.data
      assert_equal 'map-single', mutated_init.headers['header'].data
      assert_equal 'obj1-obj2-repeated', mutated_init.last_completion_result.payloads.first.data
      assert_equal 'saobj-single', mutated_init.search_attributes.indexed_fields['sakey'].data
      assert_equal 'single-single', mutated_succ.commands.first.complete_workflow_execution.result.data
      assert_equal 'samap-single',
                   mutated_succ.commands.last.upsert_workflow_search_attributes.search_attributes['sakey'].data

      # Skip search attributes
      visitor = Temporalio::Api::PayloadVisitor.new(skip_search_attributes: true, &mutator)
      mutated_act = act.class.decode(act.class.encode(act))
      mutated_succ = succ.class.decode(succ.class.encode(succ))
      visitor.run(mutated_act)
      visitor.run(mutated_succ)
      mutated_init = mutated_act.jobs.first.initialize_workflow
      assert_equal 'map-single', mutated_init.headers['header'].data
      assert_equal 'saobj', mutated_init.search_attributes.indexed_fields['sakey'].data
      assert_equal 'single-single', mutated_succ.commands.first.complete_workflow_execution.result.data
      assert_equal 'samap', mutated_succ.commands.last.upsert_workflow_search_attributes.search_attributes['sakey'].data

      # On enter/exit
      entered = []
      exited = []
      Temporalio::Api::PayloadVisitor.new(
        on_enter: proc { |v| entered << v.class.descriptor.name },
        on_exit: proc { |v| exited << v.class.descriptor.name }
      ) do
        # Do nothing
      end.run(act)
      assert_equal entered.sort, exited.sort
      assert_includes entered, 'coresdk.workflow_activation.InitializeWorkflow'
      assert_includes entered, 'temporal.api.common.v1.Payloads'
    end

    def test_any
      protocol = Temporalio::Api::Protocol::V1::Message.new(
        body: Google::Protobuf::Any.pack(
          Temporalio::Api::History::V1::WorkflowExecutionStartedEventAttributes.new(
            input: Temporalio::Api::Common::V1::Payloads.new(
              payloads: [Temporalio::Api::Common::V1::Payload.new(data: 'payload1')]
            ),
            search_attributes: Temporalio::Api::Common::V1::SearchAttributes.new(
              indexed_fields: { 'foo' => Temporalio::Api::Common::V1::Payload.new(data: 'payload2') }
            )
          )
        )
      )
      Temporalio::Api::PayloadVisitor.new(skip_search_attributes: true, traverse_any: true) do |p|
        case p
        when Temporalio::Api::Common::V1::Payload
          p.data += '-visited'
        when Enumerable
          p.each { |v| v.data += '-visited' }
        end
      end.run(protocol)
      attrs = protocol.body.unpack(Temporalio::Api::History::V1::WorkflowExecutionStartedEventAttributes)
      assert_equal 'payload1-visited', attrs.input.payloads.first.data
      assert_equal 'payload2', attrs.search_attributes.indexed_fields['foo'].data
    end
  end
end
