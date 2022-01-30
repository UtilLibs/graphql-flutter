import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:graphql/client.dart';
import 'package:graphql_flutter_bloc_example/blocs/repos/events.dart';
import 'package:graphql_flutter_bloc_example/blocs/repos/models.dart';
import 'package:graphql_flutter_bloc_example/blocs/repos/states.dart';
import 'package:graphql_flutter_bloc_example/repository.dart';

class MyGithubReposBloc extends Bloc<MyGithubReposEvent, MyGithubReposState> {
  final GithubRepository? githubRepository;

  // this a bit of a hack
  List<Repo> githubRepositories = [];

  MyGithubReposBloc({required this.githubRepository}) : super(ReposLoading());

  // TODO refactoring this class with the block 8.0
  Stream<MyGithubReposState> mapEventToState(
    MyGithubReposEvent event,
  ) async* {
    try {
      if (event is LoadMyRepos) {
        yield* _mapReposToState(event.numOfReposToLoad);
        // } else if (event is UpdateReposAfterMutations) {
        //   yield* _mapUpdateAfterMutatationToState(event.repo);
      } else if (event is MutateToggleStar) {
        yield* _mapMutateStarRepositoryToState(event.repo!);
      }
    } catch (_, stackTrace) {
      print('$_ $stackTrace');
    }
  }

  Stream<MyGithubReposState> _mapReposToState(int numOfRepositories) async* {
    try {
      yield ReposLoading();

      final queryResults =
          await this.githubRepository!.getRepositories(numOfRepositories);

      if (queryResults.hasException) {
        yield ReposNotLoaded(queryResults.exception!.graphqlErrors);
        return;
      }

      final List<dynamic> repos = queryResults.data!['viewer']['repositories']
          ['nodes'] as List<dynamic>;

      final List<Repo> listOfRepos = repos
          .map((dynamic e) => Repo(
                id: e['id'] as String?,
                name: e['name'] as String?,
                viewerHasStarred: e['viewerHasStarred'] as bool?,
              ))
          .toList();

      githubRepositories = listOfRepos;

      // pass the data instead
      yield ReposLoaded(results: listOfRepos);
    } catch (error) {
      yield ReposNotLoaded(error as List<GraphQLError>);
    }
  }

  // Stream<MyGithubReposState> _mapUpdateAfterMutatationToState(
  //     Repo repo) async* {
  //   try {
  //     // assert(githubRepositories != null);

  //     var repos = githubRepositories
  //         .map((Repo r) => repo.id == r.id ? repo : r)
  //         .toList();
  //     yield ReposLoaded(repos);
  //   } catch (error) {
  //     yield ReposNotLoaded(error);
  //   }
  // }

  Stream<MyGithubReposState> _mapMutateStarRepositoryToState(Repo repo) async* {
    try {
      final loadingRepo = Repo(
        id: repo.id,
        name: repo.name,
        viewerHasStarred: repo.viewerHasStarred,
        isLoading: true,
      );

      // mark repo as loading
      githubRepositories = githubRepositories
          .map((Repo r) => repo.id == r.id ? loadingRepo : r)
          .toList();

      // pass the data instead
      yield ReposLoaded(results: githubRepositories);

      final queryResults = await githubRepository!.toggleRepoStar(repo);

      if (queryResults.hasException) {
        // @TODO Improve error handling here, may be introduce a hasError Method
        yield ReposNotLoaded(queryResults.exception!.graphqlErrors);
        return;
      }

      var mutatedRepo = extractRepositoryData(queryResults.data ?? {})!;

      final notloadingRepo = Repo(
        id: repo.id,
        name: repo.name,
        viewerHasStarred: mutatedRepo['viewerHasStarred'],
        isLoading: false,
      );

      githubRepositories = githubRepositories
          .map((Repo r) => repo.id == r.id ? notloadingRepo : r)
          .toList();

      yield ReposLoaded(results: githubRepositories);
    } catch (error) {
      yield ReposNotLoaded(error as List<GraphQLError>);
    }
  }

  Map<String, dynamic>? extractRepositoryData(Map<String, dynamic> data) {
    final Map<String, dynamic> action = data['action'] as Map<String, dynamic>;
    return action['starrable'] as Map<String, dynamic>?;
  }
}
